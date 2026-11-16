import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api/hg_api.dart';
import '../utils/hg_download_manager.dart';
import 'hg_notification_service.dart';
import 'hg_settings.dart';

const _taskName = 'com.guomu.huangguo.update-check';

@pragma('vm:entry-point')
void hgBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications =
        prefs.getBool(HgSettingsKeys.notificationsEnabled) ?? true;
    final source =
        prefs.getString('guomu.hg.source.active') ?? kHgDefaultBaseUrl;
    final api = HgApi(baseUrl: source, preferences: prefs);
    final manager = HgDownloadManager(api, prefs)
      ..onUpdateFound = (task, count) async {
        if (notifications) {
          await HgNotificationService.showDramaUpdate(task, count);
        }
      };
    await manager.restore();
    await manager.checkForUpdates();
    return true;
  });
}

abstract final class HgBackgroundWorker {
  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await Workmanager().initialize(hgBackgroundDispatcher);
    } catch (_) {
      // 某些旧设备或 Windows/Linux 开发环境没有后台任务能力。
    }
  }

  static Future<void> syncSchedule() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(HgSettingsKeys.backgroundUpdates) ?? true;
    try {
      if (enabled) {
        await Workmanager().registerPeriodicTask(
          _taskName,
          _taskName,
          frequency: const Duration(hours: 24),
          initialDelay: const Duration(minutes: 30),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
      } else {
        await Workmanager().cancelByUniqueName(_taskName);
      }
    } catch (_) {
      // 后台调度失败时仍保留前台启动检查。
    }
  }
}
