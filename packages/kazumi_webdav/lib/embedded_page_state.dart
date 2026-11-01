import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/app_module.dart';
import 'package:kazumi/app_widget.dart';
import 'package:kazumi/bean/dialog/dialog.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/embedded_state.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/embedded_page.dart';

/// Owns bootstrap and nested navigation for the embedded Kazumi module.
class KazumiEmbeddedPageState extends State<KazumiEmbeddedPage> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await KazumiEmbeddedBootstrap.initialize();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text('Kazumi 动漫模块初始化失败'),
              const SizedBox(height: 8),
              SelectableText('$error'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _error = null);
                  unawaited(_initialize());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_ready) return const Center(child: CircularProgressIndicator());

    return ModularApp(
      module: appModule,
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [KazumiDialog.observer, rootRouteObserver],
      defaultTransition: TransitionType.material,
      provide: (scoped) {
        scoped.addChangeNotifier<ThemeProvider>(ThemeProvider.new);
      },
      child: AppWidget(embedded: true, hostTheme: Theme.of(context)),
    );
  }
}
