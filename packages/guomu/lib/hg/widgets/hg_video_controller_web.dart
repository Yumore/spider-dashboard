import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('Hls')
extension type _Hls._(JSObject _) implements JSObject {
  external factory _Hls();
  external static bool isSupported();
  external void loadSource(String source);
  external void attachMedia(web.HTMLVideoElement media);
  external void destroy();
}

class HgVideoController extends ChangeNotifier {
  HgVideoController({
    required this.url,
    required this.headers,
    this.localPath,
    this.onEnded,
  });

  static int _nextId = 0;

  final String url;
  final String? localPath;
  final Map<String, String> headers;
  final VoidCallback? onEnded;

  late final String _viewType;
  web.HTMLVideoElement? _video;
  _Hls? _hls;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _ready = false;
  String? _error;
  bool _playing = false;
  bool _ended = false;
  double _progress = 0;
  double _aspectRatio = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _pendingSeek;
  double _volume = 1;
  bool _autoplayMuted = false;

  bool get isReady => _ready;
  bool get hasError => _error != null;
  String? get errorDescription => _error;
  bool get isPlaying => _playing;
  double get progress => _progress;
  double get aspectRatio => _aspectRatio;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;

  Future<void> initialize() async {
    _viewType = 'guomu-hls-${_nextId++}';
    final video = web.HTMLVideoElement()
      ..autoplay = false
      ..controls = false
      ..muted = false
      ..preload = 'auto'
      ..setAttribute('playsinline', '')
      ..setAttribute('webkit-playsinline', '')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = '#000000'
      ..style.pointerEvents = 'none';
    _video = video;
    _attachVideo(video);
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (viewId) => video,
    );
  }

  void _attachVideo(web.HTMLVideoElement video) {
    _subscriptions.add(
      video.onCanPlay.listen((_) {
        _ready = true;
        _error = null;
        _applyPendingSeek();
        notifyListeners();
      }),
    );
    _subscriptions.add(
      video.onPlay.listen((_) {
        _playing = true;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      video.onPause.listen((_) {
        _playing = false;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      video.onLoadedMetadata.listen((_) {
        final width = video.videoWidth.toDouble();
        final height = video.videoHeight.toDouble();
        if (width > 0 && height > 0) _aspectRatio = width / height;
        final duration = video.duration;
        if (duration.isFinite && duration > 0) {
          _duration = Duration(milliseconds: (duration * 1000).round());
        }
        _applyPendingSeek();
        notifyListeners();
      }),
    );
    _subscriptions.add(
      video.onError.listen((_) {
        _error = video.error?.message;
        _ready = false;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      video.onDurationChange.listen((_) {
        final duration = video.duration;
        if (duration.isFinite && duration > 0) {
          _duration = Duration(milliseconds: (duration * 1000).round());
          _applyPendingSeek();
          notifyListeners();
        }
      }),
    );
    _subscriptions.add(
      video.onTimeUpdate.listen((_) {
        final duration = video.duration;
        if (duration.isFinite && duration > 0) {
          _position = Duration(
            milliseconds: (video.currentTime * 1000).round(),
          );
          _duration = Duration(milliseconds: (duration * 1000).round());
          _progress = (video.currentTime / duration).clamp(0.0, 1.0);
          notifyListeners();
        }
      }),
    );
    _subscriptions.add(
      video.onEnded.listen((_) {
        if (_ended) return;
        _ended = true;
        _playing = false;
        onEnded?.call();
      }),
    );

    if (_Hls.isSupported()) {
      _hls = _Hls()
        ..loadSource(url)
        ..attachMedia(video);
    } else if (video.canPlayType('application/vnd.apple.mpegurl') != '') {
      video.src = url;
    }
  }

  Widget buildView() => HtmlElementView(viewType: _viewType);

  Future<void> play({bool userInitiated = false}) async {
    final video = _video;
    if (video == null) return;
    try {
      if (userInitiated) {
        _autoplayMuted = false;
        video.muted = false;
      }
      await video.play().toDart;
    } catch (_) {
      if (userInitiated) return;
      try {
        _autoplayMuted = true;
        video.muted = true;
        await video.play().toDart;
      } catch (_) {
        // 自动播放被浏览器拦截时，保留封面和手动播放入口。
      }
    }
  }

  Future<void> pause() async {
    _video?.pause();
  }

  Future<void> toggle() async {
    if (_video == null) return;
    if (_playing) {
      await pause();
    } else {
      await play(userInitiated: true);
    }
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 1);
    final video = _video;
    if (video != null) {
      video.volume = _volume;
      video.muted = _autoplayMuted && _volume <= 0;
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final video = _video;
    if (video != null) video.playbackRate = speed;
  }

  Future<void> seekTo(Duration position) async {
    final video = _video;
    if (video == null) return;
    final seconds = position.inMilliseconds / 1000;
    final duration = video.duration;
    final target = seconds < 0
        ? 0.0
        : (duration.isFinite && duration > 0 && seconds > duration
              ? duration
              : seconds);
    if (!_ready || !video.duration.isFinite || video.duration <= 0) {
      _pendingSeek = Duration(milliseconds: (target * 1000).round());
      return;
    }
    _pendingSeek = null;
    video.currentTime = target;
    _position = Duration(milliseconds: (target * 1000).round());
    notifyListeners();
  }

  void _applyPendingSeek() {
    final video = _video;
    final pending = _pendingSeek;
    if (video == null ||
        pending == null ||
        !video.duration.isFinite ||
        video.duration <= 0) {
      return;
    }
    final target = (pending.inMilliseconds / 1000).clamp(0.0, video.duration);
    video.currentTime = target;
    _position = Duration(milliseconds: (target * 1000).round());
    _pendingSeek = null;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _hls?.destroy();
    final video = _video;
    if (video != null) {
      video.pause();
      video.remove();
    }
    super.dispose();
  }
}
