import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/hg_api.dart';
import '../services/hg_settings.dart';
import '../models/hg_download_models.dart';
import '../models/hg_models.dart';
import 'hg_hls_downloader_native.dart';

class HgDownloadManager extends ChangeNotifier {
  HgDownloadManager(this._api, this._prefs);

  static const _storageKey = 'guomu.downloads.v1';
  final HgApi _api;
  final SharedPreferences _prefs;
  final List<HgDownloadTask> _tasks = [];
  Future<void> _queue = Future<void>.value();
  bool _restored = false;

  Future<void> Function(HgDownloadTask task, int newEpisode)? onUpdateFound;
  Future<void> Function(HgDownloadTask task)? onDownloadCompleted;

  List<HgDownloadTask> get tasks => List.unmodifiable(_tasks);
  bool get autoUpdateDefault =>
      _prefs.getBool(HgSettingsKeys.autoUpdateDownloads) ?? true;

  HgDownloadTask? taskFor(int videoId) {
    for (final task in _tasks) {
      if (task.videoId == videoId) return task;
    }
    return null;
  }

  bool isEpisodeDownloaded(int videoId, int episode) {
    return taskFor(videoId)?.episodes.containsKey(episode) ?? false;
  }

  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final restored = HgDownloadTask.decodeList(_prefs.getString(_storageKey));
    for (final task in restored) {
      final episodes = <int, HgDownloadedEpisode>{};
      for (final episode in task.episodes.values) {
        if (await File(episode.manifestPath).exists()) {
          episodes[episode.number] = episode;
        }
      }
      _tasks.add(task.copyWith(episodes: episodes));
    }
    notifyListeners();
  }

  Future<void> startDramaDownload(
    HgVideoDetail detail, {
    bool? autoUpdate,
    bool downloadNow = true,
  }) async {
    await restore();
    final shouldAutoUpdate = autoUpdate ?? autoUpdateDefault;
    final existing = taskFor(detail.id);
    final initial =
        existing ??
        HgDownloadTask(
          videoId: detail.id,
          title: detail.title,
          cover: detail.cover,
          tags: detail.tags,
          totalEpisodes: _episodeCount(detail),
          autoUpdate: shouldAutoUpdate,
          lastKnownEpisode: _episodeCount(detail),
          updatedAt: DateTime.now().toIso8601String(),
        );
    final task = initial.copyWith(
      title: detail.title,
      cover: detail.cover,
      tags: detail.tags,
      totalEpisodes: _episodeCount(detail),
      autoUpdate: shouldAutoUpdate,
      tracking: true,
      state: downloadNow ? '下载中' : '追更中',
      lastError: '',
      lastKnownEpisode: _episodeCount(detail),
      updatedAt: DateTime.now().toIso8601String(),
    );
    _upsert(task);
    await _persist();
    if (downloadNow) {
      _enqueue(() => _downloadAll(detail));
    }
  }

  Future<void> setAutoUpdate(int videoId, bool value) async {
    await restore();
    final task = taskFor(videoId);
    if (task == null) return;
    _upsert(task.copyWith(autoUpdate: value, tracking: true));
    await _persist();
  }

  Future<void> toggleTracking(int videoId, bool value) async {
    await restore();
    final task = taskFor(videoId);
    if (task == null) return;
    _upsert(task.copyWith(tracking: value));
    await _persist();
  }

  Future<void> checkForUpdates() async {
    await restore();
    final candidates = _tasks
        .where((task) => task.tracking)
        .toList(growable: false);
    for (final task in candidates) {
      try {
        final detail = await _api.video(task.videoId);
        final count = _episodeCount(detail);
        final previous = task.lastKnownEpisode;
        if (count > previous) {
          final updated = task.copyWith(
            title: detail.title,
            cover: detail.cover,
            tags: detail.tags,
            totalEpisodes: count,
            lastKnownEpisode: count,
            state: task.autoUpdate ? '检查更新' : '有新剧集',
            updatedAt: DateTime.now().toIso8601String(),
          );
          _upsert(updated);
          await _persist();
          await onUpdateFound?.call(updated, count - previous);
          if (task.autoUpdate) {
            unawaited(startDramaDownload(detail));
          }
        }
      } catch (_) {
        // 单部剧更新检查失败不影响其他剧。
      }
    }
  }

  Future<String?> localPlaylist(int videoId, int episode) async {
    await restore();
    final task = taskFor(videoId);
    final item = task?.episodes[episode];
    if (item == null) return null;
    return await File(item.manifestPath).exists() ? item.manifestPath : null;
  }

  Future<int> sizeBytes() async {
    await restore();
    var total = 0;
    for (final task in _tasks) {
      total += task.downloadedBytes;
    }
    return total;
  }

  Future<void> remove(int videoId) async {
    await restore();
    _tasks.removeWhere((task) => task.videoId == videoId);
    await _deleteDirectory(await _dramaDirectory(videoId));
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    await restore();
    final dir = await _downloadRoot();
    if (await dir.exists()) await dir.delete(recursive: true);
    _tasks.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _downloadAll(HgVideoDetail detail) async {
    final task = taskFor(detail.id);
    if (task == null) return;
    final episodes = _episodes(detail);
    final directory = await _dramaDirectory(detail.id);
    var completed = task.episodes;
    for (final episode in episodes) {
      if (taskFor(detail.id)?.episodes.containsKey(episode.number) ?? false) {
        continue;
      }
      _upsert(
        taskFor(detail.id)!.copyWith(
          state: '下载中',
          lastError: '',
          progress: completed.length / episodes.length.clamp(1, 99999),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      try {
        final info = await _api.playback(detail.id, episode.number);
        final mediaHeaders = <String, String>{
          ...hgMediaHeaders(),
          if (info.cdnAuthKey.isNotEmpty) info.cdnAuthKey: info.cdnAuthValue,
          if (info.cdnApp.isNotEmpty) 'x-cdn-app': info.cdnApp,
        };
        final episodeDir = Directory('${directory.path}/${episode.number}');
        final stopwatch = Stopwatch()..start();
        var lastBytes = 0;
        final downloaded = await HgHlsDownloader.download(
          dio: Dio(),
          playlistUrl: info.videoUrl,
          directory: episodeDir,
          headers: mediaHeaders,
          onProgress: (bytes, _) {
            final current = taskFor(detail.id);
            if (current == null) return;
            final elapsed = stopwatch.elapsedMilliseconds.clamp(1, 60000);
            final speed = ((bytes - lastBytes) * 1000 / elapsed).round();
            lastBytes = bytes;
            _upsert(
              current.copyWith(
                state: '下载中',
                receivedBytes: current.downloadedBytes + bytes,
                totalBytes: current.downloadedBytes + bytes,
                speedBytesPerSecond: speed,
                progress:
                    (completed.length + 0.45) / episodes.length.clamp(1, 99999),
                updatedAt: DateTime.now().toIso8601String(),
              ),
            );
          },
        );
        completed = {
          ...completed,
          episode.number: HgDownloadedEpisode(
            number: episode.number,
            directory: downloaded.directory,
            manifestPath: downloaded.manifestPath,
            bytes: downloaded.bytes,
            updatedAt: DateTime.now().toIso8601String(),
          ),
        };
        _upsert(
          taskFor(detail.id)!.copyWith(
            episodes: completed,
            progress: completed.length / episodes.length.clamp(1, 99999),
            state: completed.length >= episodes.length ? '已缓存' : '下载中',
            speedBytesPerSecond: 0,
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        await _persist();
      } catch (error) {
        final current = taskFor(detail.id);
        if (current != null) {
          _upsert(
            current.copyWith(
              state: '部分缓存',
              lastError: error.toString(),
              receivedBytes: current.downloadedBytes,
              speedBytesPerSecond: 0,
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
        }
      }
    }
    final current = taskFor(detail.id);
    if (current != null) {
      final finished = current.copyWith(
        totalEpisodes: episodes.length,
        progress: completed.length / episodes.length.clamp(1, 99999),
        state: completed.length >= episodes.length ? '已缓存' : '部分缓存',
        speedBytesPerSecond: 0,
        updatedAt: DateTime.now().toIso8601String(),
      );
      _upsert(finished);
      await _persist();
      if (finished.isComplete) await onDownloadCompleted?.call(finished);
    }
  }

  void _enqueue(Future<void> Function() action) {
    _queue = _queue.catchError((Object _) {}).then((_) => action());
  }

  void _upsert(HgDownloadTask task) {
    final index = _tasks.indexWhere((item) => item.videoId == task.videoId);
    if (index < 0) {
      _tasks.add(task);
    } else {
      _tasks[index] = task;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _storageKey,
      jsonEncode(_tasks.map((task) => task.toJson()).toList()),
    );
  }

  Future<Directory> _downloadRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/guomu/downloads');
  }

  Future<Directory> _dramaDirectory(int videoId) async {
    return Directory('${(await _downloadRoot()).path}/$videoId');
  }

  Future<void> _deleteDirectory(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static int _episodeCount(HgVideoDetail detail) {
    if (detail.episodes.isNotEmpty) return detail.episodes.length;
    return detail.totalEpisodes > 0
        ? detail.totalEpisodes
        : detail.episodeCount;
  }

  static List<HgEpisode> _episodes(HgVideoDetail detail) {
    if (detail.episodes.isNotEmpty) return detail.episodes;
    final count = _episodeCount(detail);
    return List.generate(
      count.clamp(0, 999),
      (index) => HgEpisode(number: index + 1, title: '${index + 1}'),
      growable: false,
    );
  }
}
