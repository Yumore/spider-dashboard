import 'package:flutter/material.dart';

/// Web fallback because the upstream desktop/mobile application uses dart:io.
class PureLiveEmbeddedPage extends StatelessWidget {
  const PureLiveEmbeddedPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('Pure Live 当前仅支持 Android、iOS、Windows、macOS 与 Linux。'),
    ),
  );
}
