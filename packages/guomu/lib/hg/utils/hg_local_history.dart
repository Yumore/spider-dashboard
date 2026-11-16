import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hg_models.dart';

/// 本机播放历史。它是软件内所有“继续观看”入口的唯一进度来源。
abstract final class HgLocalHistory {
  static const _key = 'guomu.local.history.v1';
  static const _limit = 60;

  // 播放器会周期性保存进度，串行化写入避免旧进度覆盖新进度。
  static Future<void> _writeTail = Future<void>.value();

  static Future<List<HgPlaylistItem>> load() async {
    await _writeTail.catchError((Object _) {});
    return _loadDirect();
  }

  static Future<HgPlaylistItem?> find(int videoId) async {
    final items = await load();
    for (final item in items) {
      if (item.dramaId == videoId) return item;
    }
    return null;
  }

  static Future<void> save({
    required int videoId,
    required String title,
    required String cover,
    required int episode,
    required int totalEpisodes,
    int positionMs = 0,
    int durationMs = 0,
  }) {
    if (videoId <= 0) return Future<void>.value();
    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      final current = await _loadDirect();
      final now = DateTime.now().toIso8601String();
      final next = <HgPlaylistItem>[
        HgPlaylistItem(
          id: videoId,
          videoId: videoId,
          title: title,
          cover: cover,
          lastEpisode: episode,
          totalEpisodes: totalEpisodes,
          positionMs: positionMs < 0 ? 0 : positionMs,
          durationMs: durationMs < 0 ? 0 : durationMs,
          updatedAt: now,
        ),
        ...current.where((item) => item.dramaId != videoId),
      ].take(_limit).toList(growable: false);
      await prefs.setString(_key, jsonEncode(next.map(_toJson).toList()));
    });
  }

  static Future<void> remove(int videoId) {
    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      final current = await _loadDirect();
      final next = current
          .where((item) => item.dramaId != videoId)
          .toList(growable: false);
      await prefs.setString(_key, jsonEncode(next.map(_toJson).toList()));
    });
  }

  static Future<void> clear() {
    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    });
  }

  static Future<List<HgPlaylistItem>> _loadDirect() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map(
            (item) => HgPlaylistItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.dramaId > 0)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeTail = _writeTail.catchError((Object _) {}).then<void>((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static Map<String, dynamic> _toJson(HgPlaylistItem item) => {
    'id': item.dramaId,
    'video_id': item.dramaId,
    'title': item.title,
    'cover': item.cover,
    'last_ep': item.lastEpisode,
    'total_ep': item.totalEpisodes,
    'position_ms': item.positionMs,
    'duration_ms': item.durationMs,
    'updated_at': item.updatedAt,
  };
}
