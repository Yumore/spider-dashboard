import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/live_activity_file.dart';

/// iOS 灵动岛/锁屏实时活动。插件只在 iOS 16.1+ 生效，其他平台安全跳过。
abstract final class HgLiveActivityService {
  static const appGroupId = 'group.com.guomu.huangguo';
  static String _configuredAppGroupId = appGroupId;
  static const _activityId = 'guomu-now-playing';
  static final LiveActivities _plugin = LiveActivities();
  static bool _initialized = false;

  static bool get _supported {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  static void configureAppGroup(String appGroupId) {
    if (_initialized && _configuredAppGroupId != appGroupId) {
      throw StateError('The Live Activity App Group is already initialized.');
    }
    _configuredAppGroupId = appGroupId;
  }

  static Future<void> initialize() async {
    if (!_supported || _initialized) return;
    try {
      await _plugin.init(appGroupId: _configuredAppGroupId, urlScheme: 'guomu');
      _initialized = true;
    } catch (error) {
      debugPrint('Guomu live activity init skipped: $error');
      // 未签名开发包或设备不支持时不影响播放器。
    }
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
  }) async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    try {
      final supported = await _plugin.areActivitiesSupported();
      if (!supported) return;
      final enabled = await _plugin.areActivitiesEnabled();
      if (!enabled) return;
      final data = <String, dynamic>{
        'videoId': videoId,
        'title': title,
        'cover': cover.isEmpty
            ? null
            : LiveActivityFileFromUrl.image(
                cover,
                imageOptions: LiveActivityImageFileOptions(resizeFactor: 0.16),
              ),
        'genre': tags.isEmpty ? '黄果短剧' : tags.take(2).join(' · '),
        'episode': episode,
        'totalEpisodes': totalEpisodes,
        'episodeLabel':
            '观看至 $episode${totalEpisodes > 0 ? '/$totalEpisodes' : ''} 集',
        'progress': progress.clamp(0.0, 1.0),
        'deepLink': deepLink,
      };
      try {
        await _plugin.createOrUpdateActivity(
          _activityId,
          data,
          staleIn: const Duration(hours: 3),
          removeWhenAppIsKilled: false,
        );
      } catch (error) {
        debugPrint('Guomu live activity cover skipped: $error');
        data['cover'] = null;
        await _plugin.createOrUpdateActivity(
          _activityId,
          data,
          staleIn: const Duration(hours: 3),
          removeWhenAppIsKilled: false,
        );
      }
    } catch (error) {
      debugPrint('Guomu live activity update skipped: $error');
      // 实时活动是增强能力，失败不阻断播放器。
    }
  }

  static Future<void> end() async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    try {
      await _plugin.endActivity(_activityId);
    } catch (_) {}
  }
}
