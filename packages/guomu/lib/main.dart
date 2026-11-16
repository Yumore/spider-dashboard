import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hg/app.dart';
import 'hg/services/hg_background_worker.dart';
import 'hg/services/hg_notification_service.dart';
import 'hg/theme/hg_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _GuomuBootstrapApp());
}

class _GuomuBootstrapApp extends StatefulWidget {
  const _GuomuBootstrapApp();

  @override
  State<_GuomuBootstrapApp> createState() => _GuomuBootstrapAppState();
}

class _GuomuBootstrapAppState extends State<_GuomuBootstrapApp> {
  SharedPreferences? _preferences;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_startupError != null && mounted) {
      setState(() => _startupError = null);
    }

    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 8),
      );
      await _configureSystemChrome();
      if (!mounted) return;
      setState(() => _preferences = preferences);

      // Let the native-looking launch screen paint before optional plugins run.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) unawaited(_initializeDeferredServices());
    } catch (error, stackTrace) {
      debugPrint('Guomu startup failed: $error\n$stackTrace');
      if (mounted) setState(() => _startupError = error);
    }
  }

  Future<void> _configureSystemChrome() async {
    if (kIsWeb) return;
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]).timeout(const Duration(seconds: 3));
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      ).timeout(const Duration(seconds: 3));
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );
    } catch (error) {
      // Window styling must never prevent the app from reaching its first frame.
      debugPrint('Guomu system chrome initialization skipped: $error');
    }
  }

  Future<void> _initializeDeferredServices() async {
    if (kIsWeb) return;
    try {
      await HgNotificationService.initialize().timeout(
        const Duration(seconds: 8),
      );
    } catch (error) {
      debugPrint('Guomu notification initialization skipped: $error');
    }
    try {
      await HgBackgroundWorker.initialize().timeout(
        const Duration(seconds: 10),
      );
      await HgBackgroundWorker.syncSchedule().timeout(
        const Duration(seconds: 10),
      );
    } catch (error) {
      debugPrint('Guomu background worker initialization skipped: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;
    if (preferences != null) return GuomuApp(preferences: preferences);
    return _GuomuLaunchApp(
      failed: _startupError != null,
      onRetry: () => unawaited(_bootstrap()),
    );
  }
}

class _GuomuLaunchApp extends StatelessWidget {
  const _GuomuLaunchApp({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '果幕',
      debugShowCheckedModeBanner: false,
      theme: buildHgTheme(Brightness.light),
      darkTheme: buildHgTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        backgroundColor: const Color(0xFF0C0D10),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF9A62), Color(0xFFE94424)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x44FF6B3D),
                          blurRadius: 36,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFFFFF8F2),
                      size: 58,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '果幕',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    failed ? '本地数据初始化失败' : '正在准备你的剧场',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (failed)
                    FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B3D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('重新加载'),
                    )
                  else
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6B3D),
                        strokeWidth: 2.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
