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
  final Set<int> _queuedVideoIds = <int>{};
  Future<void> _queue = Future<void>.value();
  bool _restored = false;
  Future<void>? _restoring;
  bool _resuming = false;

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

  Future<void> restore() {
    if (_restored) return Future<void>.value();
    return _restoring ??= _restore();
  }

  Future<void> _restore() async {
    // localPlaylist may be called from a player's initState. Notify only after
    // that build has finished, and let concurrent callers await the same load.
    await Future<void>.value();
    final restored = HgDownloadTask.decodeList(_prefs.getString(_storageKey));
    final interrupted = <HgDownloadTask>[];
    for (final task in restored) {
      final episodes = <int, HgDownloadedEpisode>{};
      for (final episode in task.episodes.values) {
        if (await File(episode.manifestPath).exists()) {
          episodes[episode.number] = episode;
        }
      }
      var normalized = task.copyWith(
        episodes: episodes,
        speedBytesPerSecond: 0,
      );
      if (normalized.isDownloading) {
        normalized = normalized.copyWith(state: '等待恢复');
        interrupted.add(normalized);
      }
      _tasks.add(normalized);
    }
    _restored = true;
    notifyListeners();
    if (interrupted.isNotEmpty) {
      unawaited(_resumeInterrupted(interrupted));
    }
  }

  Future<void> _resumeInterrupted(List<HgDownloadTask> interrupted) async {
    if (_resuming) return;
    _resuming = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      for (final task in interrupted) {
        if (taskFor(task.videoId) == null) continue;
        try {
          final detail = await _api.video(task.videoId);
          await startDramaDownload(
            detail,
            autoUpdate: task.autoUpdate,
            downloadNow: true,
          );
        } catch (error) {
          final current = taskFor(task.videoId);
          if (current != null) {
            _upsert(
              current.copyWith(
                state: '已暂停',
                speedBytesPerSecond: 0,
                lastError: error.toString(),
                updatedAt: DateTime.now().toIso8601String(),
              ),
            );
          }
        }
      }
    } finally {
      _resuming = false;
    }
  }

  Future<void> startDramaDownload(
    HgVideoDetail detail, {
    bool? autoUpdate,
    bool downloadNow = true,
  }) async {
    await restore();
    final existing = taskFor(detail.id);
    final shouldAutoUpdate =
        autoUpdate ?? existing?.autoUpdate ?? autoUpdateDefault;
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
      state: downloadNow ? '排队中' : '追更中',
      progress: initial.episodes.length / _episodeCount(detail).clamp(1, 99999),
      receivedBytes: initial.downloadedBytes,
      totalBytes: initial.downloadedBytes,
      speedBytesPerSecond: 0,
      lastError: '',
      lastKnownEpisode: _episodeCount(detail),
      updatedAt: DateTime.now().toIso8601String(),
    );
    _upsert(task);
    await _persist();
    if (downloadNow) {
      _enqueueDownload(detail);
    }
  }

  Future<void> resumeDownload(int videoId) async {
    await restore();
    final task = taskFor(videoId);
    if (task == null) return;
    final detail = await _api.video(videoId);
    await startDramaDownload(
      detail,
      autoUpdate: task.autoUpdate,
      downloadNow: true,
    );
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
      if (taskFor(detail.id) == null) return;
      if (taskFor(detail.id)?.episodes.containsKey(episode.number) ?? false) {
        continue;
      }
      final episodeDir = Directory('${directory.path}/${episode.number}');
      if (await episodeDir.exists()) {
        await episodeDir.delete(recursive: true);
      }
      final completedBytes = completed.values.fold<int>(
        0,
        (sum, item) => sum + item.bytes,
      );
      _upsert(
        taskFor(detail.id)!.copyWith(
          state: '下载中 · 第 ${episode.number}/${episodes.length} 集',
          lastError: '',
          receivedBytes: completedBytes,
          totalBytes: completedBytes,
          speedBytesPerSecond: 0,
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
        final dio = Dio();
        final preferHevc =
            !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS) &&
            info.hevcUrl.isNotEmpty;
        var lastSpeedBytes = 0;
        var lastSpeedAt = DateTime.now();
        var lastUiAt = DateTime.fromMillisecondsSinceEpoch(0);
        var lastPersistAt = DateTime.now();
        var speed = 0;

        void onProgress(HgDownloadProgressSnapshot progress) {
          final now = DateTime.now();
          final speedElapsed = now.difference(lastSpeedAt).inMilliseconds;
          if (speedElapsed >= 500) {
            final delta = progress.receivedBytes - lastSpeedBytes;
            speed = delta <= 0 ? 0 : (delta * 1000 / speedElapsed).round();
            lastSpeedBytes = progress.receivedBytes;
            lastSpeedAt = now;
          }
          final uiElapsed = now.difference(lastUiAt).inMilliseconds;
          if (uiElapsed < 220 &&
              progress.completedSegments < progress.totalSegments) {
            return;
          }
          lastUiAt = now;
          final current = taskFor(detail.id);
          if (current == null) return;
          final episodeFraction = progress.fraction;
          _upsert(
            current.copyWith(
              state: '下载中 · 第 ${episode.number}/${episodes.length} 集',
              receivedBytes: completedBytes + progress.receivedBytes,
              totalBytes: completedBytes + progress.totalBytes,
              speedBytesPerSecond: speed,
              progress:
                  (completed.length + episodeFraction) /
                  episodes.length.clamp(1, 99999),
              updatedAt: now.toIso8601String(),
            ),
          );
          if (now.difference(lastPersistAt).inSeconds >= 5) {
            lastPersistAt = now;
            unawaited(_persist());
          }
        }

        late final HgDownloadedPlaylist downloaded;
        try {
          downloaded = await HgHlsDownloader.download(
            dio: dio,
            playlistUrl: preferHevc ? info.hevcUrl : info.videoUrl,
            directory: episodeDir,
            headers: mediaHeaders,
            onProgress: onProgress,
          );
        } catch (_) {
          if (!preferHevc) rethrow;
          if (await episodeDir.exists()) {
            await episodeDir.delete(recursive: true);
          }
          downloaded = await HgHlsDownloader.download(
            dio: dio,
            playlistUrl: info.videoUrl,
            directory: episodeDir,
            headers: mediaHeaders,
            onProgress: onProgress,
          );
        } finally {
          dio.close(force: true);
        }
        if (taskFor(detail.id) == null) {
          if (await episodeDir.exists()) {
            await episodeDir.delete(recursive: true);
          }
          return;
        }
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
        final completedTotal = completed.values.fold<int>(
          0,
          (sum, item) => sum + item.bytes,
        );
        _upsert(
          taskFor(detail.id)!.copyWith(
            episodes: completed,
            progress: completed.length / episodes.length.clamp(1, 99999),
            state: completed.length >= episodes.length ? '已缓存' : '下载中',
            receivedBytes: completedTotal,
            totalBytes: completedTotal,
            speedBytesPerSecond: 0,
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        await _persist();
      } catch (error) {
        if (await episodeDir.exists()) {
          await episodeDir.delete(recursive: true);
        }
        final current = taskFor(detail.id);
        if (current != null) {
          _upsert(
            current.copyWith(
              state: '已暂停',
              lastError: error.toString(),
              receivedBytes: completed.values.fold<int>(
                0,
                (sum, item) => sum + item.bytes,
              ),
              totalBytes: 0,
              speedBytesPerSecond: 0,
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
        }
        await _persist();
        break;
      }
    }
    final current = taskFor(detail.id);
    if (current != null) {
      final finished = current.copyWith(
        totalEpisodes: episodes.length,
        progress: completed.length / episodes.length.clamp(1, 99999),
        state: current.state == '已暂停'
            ? '已暂停'
            : completed.length >= episodes.length
            ? '已缓存'
            : '部分缓存',
        speedBytesPerSecond: 0,
        updatedAt: DateTime.now().toIso8601String(),
      );
      _upsert(finished);
      await _persist();
      if (finished.isComplete) await onDownloadCompleted?.call(finished);
    }
  }

  void _enqueueDownload(HgVideoDetail detail) {
    if (!_queuedVideoIds.add(detail.id)) return;
    _enqueue(() async {
      try {
        await _downloadAll(detail);
      } finally {
        _queuedVideoIds.remove(detail.id);
      }
    });
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
