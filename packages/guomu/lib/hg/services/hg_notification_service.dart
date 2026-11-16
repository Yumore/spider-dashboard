import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/hg_download_models.dart';

/// 本机通知只在用户设备上产生，不依赖果幕服务端。
abstract final class HgNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    const android = AndroidInitializationSettings('ic_notification');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await initialize();
    final notification = await Permission.notification.request();
    // 内部缓存目录无需存储权限；仍兼容旧版 Android 的外部下载权限提示。
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.storage.request();
    }
    return notification.isGranted || notification.isLimited;
  }

  static Future<void> showDramaUpdate(
    HgDownloadTask task,
    int newEpisodes,
  ) async {
    if (kIsWeb) return;
    await initialize();
    final countText = newEpisodes > 1 ? '$newEpisodes 集' : '1 集';
    await _plugin.show(
      task.videoId,
      '${task.title} 更新了',
      '已更新 $countText${task.autoUpdate ? '，正在自动缓存新剧集' : '，打开果幕即可继续观看'}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'guomu_updates',
          '追更提醒',
          channelDescription: '追剧更新与离线缓存提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: 'guomu_updates',
        ),
      ),
      payload: 'drama:${task.videoId}',
    );
  }

  static Future<void> showOfflineReady(HgDownloadTask task) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.show(
      task.videoId + 100000,
      '${task.title} 已缓存',
      '已完成 ${task.episodes.length} 集，断网也能继续观看',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'guomu_downloads',
          '离线缓存',
          channelDescription: '短剧下载完成提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(threadIdentifier: 'guomu_downloads'),
      ),
      payload: 'download:${task.videoId}',
    );
  }
}
