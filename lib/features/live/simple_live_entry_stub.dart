import 'package:flutter/material.dart';

/// Browser fallback because SimpleLive's app uses native playback and storage.
class SimpleLiveEmbeddedPage extends StatelessWidget {
  const SimpleLiveEmbeddedPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('SimpleLive 当前仅支持 Android、iOS、Windows 与 macOS。'),
    ),
  );
}
