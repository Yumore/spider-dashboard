import 'dart:async';

import 'package:flutter/material.dart';

/// Ignore short decoder stalls; show feedback only when waiting is noticeable.
class HgPlaybackFeedback extends StatefulWidget {
  const HgPlaybackFeedback({
    super.key,
    required this.busy,
    required this.paused,
    this.onPlay,
  });

  final bool busy;
  final bool paused;
  final VoidCallback? onPlay;

  @override
  State<HgPlaybackFeedback> createState() => _HgPlaybackFeedbackState();
}

class _HgPlaybackFeedbackState extends State<HgPlaybackFeedback> {
  Timer? _delay;
  bool _showBuffering = false;

  @override
  void initState() {
    super.initState();
    _updateBuffering();
  }

  @override
  void didUpdateWidget(covariant HgPlaybackFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) _updateBuffering();
  }

  void _updateBuffering() {
    _delay?.cancel();
    _showBuffering = false;
    if (!widget.busy) return;
    _delay = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _showBuffering = true);
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showBuffering) {
      return Center(
        child: Semantics(
          label: '视频缓冲中',
          liveRegion: true,
          child: const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    if (!widget.paused || widget.busy) return const SizedBox.shrink();
    return Center(
      child: Semantics(
        button: true,
        label: '继续播放',
        child: GestureDetector(
          key: const ValueKey('hg-playback-play-button'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPlay,
          child: Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 54,
              shadows: [Shadow(color: Colors.black54, blurRadius: 14)],
            ),
          ),
        ),
      ),
    );
  }
}
