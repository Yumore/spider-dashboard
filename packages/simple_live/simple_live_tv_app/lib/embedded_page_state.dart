import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'embedded_page.dart';
import 'main.dart';

class SimpleLiveTvEmbeddedPageState extends State<SimpleLiveTvEmbeddedPage> {
  static Future<void>? _initialization;
  static bool _hiveInitialized = false;

  Object? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      _initialization ??= _initializeServices();
      await _initialization;
      if (mounted) setState(() => _initialized = true);
    } catch (error) {
      if (!_hiveInitialized) _initialization = null;
      if (mounted) setState(() => _error = error);
    }
  }

  static Future<void> _initializeServices() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    final support = await getApplicationSupportDirectory();
    final hivePath = path.join(
      support.path,
      'dashboard',
      'simple_live_tv',
      'hive',
    );
    await Directory(hivePath).create(recursive: true);
    Hive.init(hivePath);
    _hiveInitialized = true;
    await initServices();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) return MyApp(hostTheme: Theme.of(context));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SimpleLive TV 初始化失败：$_error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => setState(() {
                  _error = null;
                  unawaited(_initialize());
                }),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
