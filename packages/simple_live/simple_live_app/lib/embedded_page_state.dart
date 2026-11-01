import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_live_app/embedded_state.dart';
import 'package:simple_live_app/embedded_page.dart';
import 'package:simple_live_app/main.dart' show MyApp;

/// Owns the isolated storage setup for the embedded SimpleLive app.
class SimpleLiveEmbeddedPageState extends State<SimpleLiveEmbeddedPage> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await SimpleLiveEmbeddedBootstrap.initialize();
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
              const Text('SimpleLive 初始化失败'),
              const SizedBox(height: 8),
              SelectableText('$error'),
            ],
          ),
        ),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return MyApp(hostTheme: Theme.of(context));
  }
}
