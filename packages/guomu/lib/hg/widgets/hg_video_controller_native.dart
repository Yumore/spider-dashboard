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
  bool _ended = false;
  bool _disposed = false;

  bool get isReady => _controller?.value.isInitialized ?? false;
  bool get isPlaying => _controller?.value.isPlaying ?? false;
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
    await controller.initialize();
    await controller.setLooping(false);
    controller.addListener(_handleVideoValue);
    _controller = controller;
    notifyListeners();
  }

  void _handleVideoValue() {
    if (_disposed) return;
    final value = _controller?.value;
    if (value != null &&
        value.isInitialized &&
        !_ended &&
        value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 180)) {
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
    await controller.seekTo(target);
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
    _disposed = true;
    _controller?.removeListener(_handleVideoValue);
    _controller?.dispose();
    super.dispose();
  }
}
