import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/hg_api.dart';
import 'auth/app_controllers.dart';
import 'pages/root_shell.dart';
import 'utils/hg_download_manager.dart';
import 'theme/hg_theme.dart';

class GuomuApp extends StatelessWidget {
  const GuomuApp({
    super.key,
    required this.preferences,
    this.onClose,
    this.embedded = false,
  });

  final SharedPreferences preferences;
  final VoidCallback? onClose;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SourceController>(
          create: (_) {
            final controller = SourceController(preferences);
            unawaited(controller.startAutoDiscovery());
            return controller;
          },
        ),
        ProxyProvider<SourceController, HgApi>(
          update: (context, source, previous) {
            previous?.setBaseUrl(source.baseUrl);
            return previous ??
                (HgApi(baseUrl: source.baseUrl, preferences: preferences)
                  ..warmStartup());
          },
        ),
        ChangeNotifierProvider<AuthController>(
          create: (context) =>
              AuthController(context.read<HgApi>(), preferences)..restore(),
        ),
        ChangeNotifierProvider<HgDownloadManager>(
          create: (context) =>
              HgDownloadManager(context.read<HgApi>(), preferences)..restore(),
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(preferences),
        ),
      ],
      child: _GuomuMaterialApp(onClose: onClose, embedded: embedded),
    );
  }
}

class _HgScrollBehavior extends MaterialScrollBehavior {
  const _HgScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _GuomuMaterialApp extends StatelessWidget {
  const _GuomuMaterialApp({this.onClose, required this.embedded});

  final VoidCallback? onClose;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeController>().mode;
    final source = context.watch<SourceController>();
    return MaterialApp(
      title: '果幕 · 黄果短剧',
      debugShowCheckedModeBanner: false,
      theme: buildHgTheme(Brightness.light, embedded: embedded),
      darkTheme: buildHgTheme(Brightness.dark, embedded: embedded),
      themeMode: themeMode,
      scrollBehavior: const _HgScrollBehavior(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
          child: MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.3,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: RootShell(key: ValueKey(source.baseUrl), onClose: onClose),
    );
  }
}
