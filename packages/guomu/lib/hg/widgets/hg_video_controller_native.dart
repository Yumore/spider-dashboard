import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

class HgVideoController extends ChangeNotifier {
  HgVideoController({
    required this.url,
    required this.headers,
    this.localPath,
    this.onEnded,
  });

  final String url;
  final String? localPath;
  final Map<String, String> headers;
  final VoidCallback? onEnded;

  VideoPlayerController? _controller;
  VideoPlayerController? _pendingController;
  final Completer<void> _cancelInitialization = Completer<void>();
  bool _ended = false;
  bool _disposed = false;
  bool _seeking = false;

  bool get isReady => _controller?.value.isInitialized ?? false;
  bool get isPlaying => _controller?.value.isPlaying ?? false;
  bool get isBuffering => _controller?.value.isBuffering ?? false;

  Duration get bufferedPosition {
    final value = _controller?.value;
    if (value == null) return Duration.zero;
    for (final range in value.buffered) {
      if (range.start <= value.position && range.end >= value.position) {
        return range.end;
      }
    }
    return value.position;
  }

  bool get hasError => _controller?.value.hasError ?? false;
  String? get errorDescription => _controller?.value.errorDescription;

  double get aspectRatio {
    final ratio = _controller?.value.aspectRatio ?? 0;
    return ratio > 0 ? ratio : 9 / 16;
  }

  Duration get position => _controller?.value.position ?? Duration.zero;

  Duration get duration => _controller?.value.duration ?? Duration.zero;

  double get volume => _controller?.value.volume ?? 1;

  double get progress {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return 0;
    final total = value.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (value.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Future<void> initialize() async {
    if (_disposed) return;
    final local = localPath?.trim() ?? '';
    final controller = local.isNotEmpty
        ? VideoPlayerController.file(
            File(local),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          )
        : VideoPlayerController.networkUrl(
            Uri.parse(url),
            httpHeaders: headers,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          );
    _pendingController = controller;
    try {
      await Future.any([controller.initialize(), _cancelInitialization.future]);
      if (!_disposed) await controller.setLooping(false);
      if (_disposed) return;
      controller.addListener(_handleVideoValue);
      _controller = controller;
      notifyListeners();
    } catch (_) {
      if (!_disposed) await controller.dispose();
      rethrow;
    } finally {
      _pendingController = null;
    }
  }

  void _handleVideoValue() {
    if (_disposed) return;
    final value = _controller?.value;
    if (value != null &&
        value.isInitialized &&
        !_seeking &&
        !_ended &&
        value.duration > Duration.zero &&
        value.isCompleted) {
      _ended = true;
      onEnded?.call();
    }
    notifyListeners();
  }

  Future<void> play({bool userInitiated = false}) async {
    await _controller?.play();
  }

  Future<void> pause() async {
    await _controller?.pause();
  }

  Future<void> toggle() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> setVolume(double value) async {
    await _controller?.setVolume(value.clamp(0, 1));
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
  }

  Future<void> seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null) return;
    final duration = controller.value.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && position > duration
              ? duration
              : position);
    _seeking = true;
    if (target < duration) _ended = false;
    try {
      await controller.seekTo(target);
    } finally {
      _seeking = false;
      _handleVideoValue();
    }
  }

  Widget buildView() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return const SizedBox.shrink();
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelInitialization.complete();
    final pending = _pendingController;
    if (pending != null && !identical(pending, _controller)) {
      unawaited(pending.dispose());
    }
    _pendingController = null;
    _controller?.removeListener(_handleVideoValue);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
