import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/hg_api.dart';
import '../models/hg_download_models.dart';
import '../models/hg_models.dart';

class HgDownloadManager extends ChangeNotifier {
  HgDownloadManager(this._api, this._prefs);

  // Web 预览不提供下载；保留构造参数以匹配原生实现。
  // ignore: unused_field
  final HgApi _api;
  // ignore: unused_field
  final SharedPreferences _prefs;

  List<HgDownloadTask> get tasks => const [];
  bool get autoUpdateDefault => true;
  HgDownloadTask? taskFor(int videoId) => null;
  bool isEpisodeDownloaded(int videoId, int episode) => false;
  Future<void> restore() async {}
  Future<void> startDramaDownload(
    HgVideoDetail detail, {
    bool? autoUpdate,
    bool downloadNow = true,
  }) async {}
  Future<void> setAutoUpdate(int videoId, bool value) async {}
  Future<void> toggleTracking(int videoId, bool value) async {}
  Future<void> checkForUpdates() async {}
  Future<String?> localPlaylist(int videoId, int episode) async => null;
  Future<int> sizeBytes() async => 0;
  Future<void> remove(int videoId) async {}
  Future<void> clear() async {}
  Future<void> Function(HgDownloadTask task, int newEpisode)? onUpdateFound;
  Future<void> Function(HgDownloadTask task)? onDownloadCompleted;
}
