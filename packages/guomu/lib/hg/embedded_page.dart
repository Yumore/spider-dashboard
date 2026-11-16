import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/hg_audio_session_service.dart';
import 'services/hg_background_worker.dart';
import 'services/hg_live_activity_service.dart';
import 'services/hg_notification_service.dart';

const guomuDashboardAppGroupId = 'group.com.nsapp.dashboard.guomu';

/// Boots the complete Guomu client inside the Dashboard navigation stack.
class GuomuEmbeddedPage extends StatefulWidget {
  const GuomuEmbeddedPage({super.key, required this.onClose});

  final VoidCallback onClose;

  static int _activeInstances = 0;
  static bool get isActive => _activeInstances > 0;

  @override
  State<GuomuEmbeddedPage> createState() => _GuomuEmbeddedPageState();
}

class _GuomuEmbeddedPageState extends State<GuomuEmbeddedPage> {
  SharedPreferences? _preferences;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    GuomuEmbeddedPage._activeInstances++;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      unawaited(HgAudioSessionService.activate());
      HgLiveActivityService.configureAppGroup(guomuDashboardAppGroupId);
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _startupError = null;
        _preferences = preferences;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) unawaited(_initializeServices());
    } catch (error) {
      if (!mounted) return;
      setState(() => _startupError = error);
    }
  }

  Future<void> _initializeServices() async {
    try {
      await HgNotificationService.initialize();
    } catch (error) {
      debugPrint('Guomu notification initialization skipped: $error');
    }
    try {
      await HgBackgroundWorker.initialize();
      await HgBackgroundWorker.syncSchedule();
    } catch (error) {
      debugPrint('Guomu background worker initialization skipped: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;
    if (preferences != null) {
      return GuomuApp(
        preferences: preferences,
        onClose: widget.onClose,
        embedded: true,
      );
    }

    final error = _startupError;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error == null)
                const CircularProgressIndicator()
              else ...[
                const Icon(Icons.error_outline_rounded, size: 36),
                const SizedBox(height: 12),
                const Text('果幕本地数据初始化失败'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _bootstrap, child: const Text('重试')),
              ],
              const SizedBox(height: 12),
              TextButton(onPressed: widget.onClose, child: const Text('返回')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    GuomuEmbeddedPage._activeInstances--;
    unawaited(HgAudioSessionService.deactivate());
    super.dispose();
  }
}
