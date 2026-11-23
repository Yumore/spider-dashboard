import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';

import '../widgets/secure_cover.dart';

/// Only property-list primitives cross the live_activities channel. In particular,
/// NSNull in createActivity raises an Objective-C exception outside Dart catches.
abstract final class HgLiveActivityService {
  static const appGroupId = 'group.com.guomu.huangguo';
  static String _configuredAppGroupId = appGroupId;
  static const _activityId = 'guomu-now-playing';
  static const _native = MethodChannel('com.guomu.huangguo/liveactivity');
  static final LiveActivities _plugin = LiveActivities();
  static final _covers = <String, String>{};
  static Future<void>? _initializing;
  static Future<void> _updates = Future<void>.value();
  static bool _initialized = false;
  static int _generation = 0;

  @visibleForTesting
  static Future<Uint8List> Function(String url)? coverLoaderForTesting;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static void configureAppGroup(String appGroupId) {
    if (_initialized && _configuredAppGroupId != appGroupId) {
      throw StateError('The Live Activity App Group is already initialized.');
    }
    _configuredAppGroupId = appGroupId;
  }

  static Future<void> initialize() async {
    if (!_supported || _initialized) return;
    await (_initializing ??= _initialize());
  }

  static Future<void> _initialize() async {
    try {
      // Container signing environments may not expose an App Group or extension.
      // Skip ActivityKit there while keeping video and Now Playing functional.
      if (await _native.invokeMethod<bool>('isAvailable') != true) return;
      await _plugin.init(appGroupId: _configuredAppGroupId, urlScheme: 'guomu');
      _initialized = true;
    } catch (error) {
      debugPrint('Guomu live activity init skipped: $error');
    } finally {
      _initializing = null;
    }
  }

  static Future<String> _coverPath(int videoId, String cover) async {
    if (cover.trim().isEmpty) return '';
    final key = '$videoId:$cover';
    final cached = _covers.remove(key);
    if (cached != null) {
      _covers[key] = cached;
      return cached;
    }
    try {
      // Reuse authenticated/decrypted covers, rather than plugin URL downloads.
      final load = coverLoaderForTesting ?? HgCoverRepository.instance.load;
      final bytes = await load(cover).timeout(const Duration(seconds: 8));
      final path = await _native.invokeMethod<String>('prepareCover', {
        'videoId': videoId,
        'bytes': bytes,
      });
      if (path != null && path.isNotEmpty) {
        _covers[key] = path;
        while (_covers.length > 4) {
          _covers.remove(_covers.keys.first);
        }
        return path;
      }
    } catch (error) {
      debugPrint('Guomu live activity cover skipped: $error');
    }
    return '';
  }

  static Future<void> showOrUpdate({
    required int videoId,
    required String title,
    required String cover,
    required List<String> tags,
    required int episode,
    required int totalEpisodes,
    required double progress,
    required String deepLink,
  }) {
    if (!_supported) return Future<void>.value();
    final generation = _generation;
    final safeTags = List<String>.of(tags);
    _updates = _updates.then((_) async {
      if (generation != _generation) return;
      await initialize();
      if (!_initialized || generation != _generation) return;
      try {
        if (!await _plugin.areActivitiesSupported() ||
            !await _plugin.areActivitiesEnabled()) {
          return;
        }
        final coverPath = await _coverPath(videoId, cover);
        if (generation != _generation) return;
        final data = <String, Object>{
          'videoId': videoId,
          'title': title,
          'cover': coverPath,
          'genre': safeTags.isEmpty ? '黄果短剧' : safeTags.take(2).join(' · '),
          'episode': episode,
          'totalEpisodes': totalEpisodes,
          'episodeLabel':
              '观看至 $episode${totalEpisodes > 0 ? '/$totalEpisodes' : ''} 集',
          'progress': progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0,
          'deepLink': deepLink,
        };
        // A failed cover stays an empty string, never null or a plugin file.
        await _plugin.createOrUpdateActivity(
          _activityId,
          data,
          staleIn: const Duration(hours: 3),
          removeWhenAppIsKilled: false,
        );
      } catch (error) {
        debugPrint('Guomu live activity update skipped: $error');
      }
    });
    return _updates;
  }

  static Future<void> end() {
    if (!_supported) return Future<void>.value();
    _generation++;
    _updates = _updates.then((_) async {
      if (!_initialized) return;
      try {
        // The logical create key is not ActivityKit's native activity identifier.
        await _plugin.endAllActivities();
      } catch (_) {}
    });
    return _updates;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    await end();
    _initialized = false;
    _initializing = null;
    _covers.clear();
    coverLoaderForTesting = null;
  }
}
