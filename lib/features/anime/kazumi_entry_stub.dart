import 'package:flutter/material.dart';

/// Browser fallback because the upstream Kazumi app depends on native plugins.
class KazumiEmbeddedPage extends StatelessWidget {
  const KazumiEmbeddedPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('Kazumi 动漫模块当前仅支持 Android、iOS、Windows、macOS 与 Linux。'),
    ),
  );
}
