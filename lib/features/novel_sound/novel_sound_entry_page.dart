import 'package:fqapp/main.dart' show FqApp, initializeNovelSoundRuntime;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NovelSoundEntryPage extends StatelessWidget {
  const NovelSoundEntryPage({super.key});

  static Future<void>? _runtimeSetup;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) return _buildUnsupportedPage(context);

    _runtimeSetup ??= initializeNovelSoundRuntime();
    return Scaffold(
      appBar: AppBar(title: const Text('什锦铺')),
      body: FutureBuilder<void>(
        future: _runtimeSetup,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '什锦铺运行环境初始化失败：${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return const ProviderScope(child: FqApp());
        },
      ),
    );
  }

  Widget _buildUnsupportedPage(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('什锦铺')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.devices_other_outlined,
                size: 44,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '该上游功能目前仅支持 Android 和 Windows。',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '本应用现有小说仍可在原书架和小说频道使用。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
