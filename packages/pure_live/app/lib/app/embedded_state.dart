import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:live_store/live_store.dart';
import 'package:pure_live/embedded.dart';
import 'package:path/path.dart' as path;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/app/bootstrap.dart';
import 'package:pure_live/app/data_root.dart';
import 'package:pure_live/app/fonts.dart';
import 'package:pure_live/app/services.dart';
import 'package:pure_live/i18n/i18n.dart';
import 'package:pure_live/platform/plugins.dart';

/// Owns Pure Live's service lifetime while it is displayed inside Dashboard.
class PureLiveEmbeddedPageState extends State<PureLiveEmbeddedPage> {
  AppServices? _services;
  FontLibrary? _fonts;
  AppStrings? _strings;
  Object? _error;
  bool _starting = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    AppServices? services;
    FontLibrary? fonts;
    try {
      services = await AppBootstrap.start(const []);
      installPluginHooks(services);
      final settings = services.store.settings;
      final language = AppLanguage.resolve(
        stored: settings.isSet(Settings.language)
            ? settings.get(Settings.language)
            : null,
        preferred: PlatformDispatcher.instance.locales,
      );
      final strings = await AppStrings.load(language, rootBundle);
      fonts = FontLibrary(
        root: Directory(path.join(services.dataRoot.path, 'fonts')),
        http: services.http,
        legacyRoots: legacyFontRoots(const []),
      );
      await fonts.restore(settings);
      if (!mounted || _disposed) {
        fonts.dispose();
        await services.close();
        return;
      }
      setState(() {
        _services = services;
        _fonts = fonts;
        _strings = strings;
        _starting = false;
      });
    } catch (error) {
      if (_disposed) {
        fonts?.dispose();
        await services?.close();
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = error;
        _starting = false;
      });
      fonts?.dispose();
      await services?.close();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _fonts?.dispose();
    final services = _services;
    if (services != null) unawaited(services.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    final fonts = _fonts;
    final strings = _strings;
    if (services != null && fonts != null && strings != null) {
      return ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          fontLibraryProvider.overrideWithValue(fonts),
          ...pluginOverrides(),
        ],
        child: PureLiveApp(
          strings: strings,
          hostTheme: Theme.of(context),
        ),
      );
    }
    if (_starting) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.live_tv_outlined, size: 40),
              const SizedBox(height: 12),
              const Text('直播模块启动失败'),
              if (error != null) ...[
                const SizedBox(height: 8),
                SelectableText('$error'),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _starting = true;
                  });
                  unawaited(_start());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
