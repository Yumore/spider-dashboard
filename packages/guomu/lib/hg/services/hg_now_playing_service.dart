import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef HgNowPlayingSeekHandler = Future<void> Function(double seconds);

/// iOS 锁屏/通知中心的系统“正在播放”信息。
abstract final class HgNowPlayingService {
  static const _channel = MethodChannel('com.guomu.huangguo/nowplaying');
  static const Map<String, String> _empty = {};
  static bool _handlerInstalled = false;
  static Future<void> Function()? _onPlay;
  static Future<void> Function()? _onPause;
  static Future<void> Function()? _onToggle;
  static HgNowPlayingSeekHandler? _onSeek;

  static bool get _supported {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<void> initialize({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onToggle,
    required HgNowPlayingSeekHandler onSeek,
  }) async {
    if (!_supported) return;
    _onPlay = onPlay;
    _onPause = onPause;
    _onToggle = onToggle;
    _onSeek = onSeek;
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'play':
          await _onPlay?.call();
          return;
        case 'pause':
          await _onPause?.call();
          return;
        case 'toggle':
          await _onToggle?.call();
          return;
        case 'seekTo':
          final seconds = (call.arguments as num?)?.toDouble();
          if (seconds != null) await _onSeek?.call(seconds);
          return;
      }
    });
  }

  static Future<void> update({
    required String title,
    required String subtitle,
    required String cover,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required double speed,
    required String deepLink,
    Map<String, String> headers = _empty,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'subtitle': subtitle,
        'cover': cover,
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'isPlaying': isPlaying,
        'speed': speed,
        'deepLink': deepLink,
        if (headers.isNotEmpty) 'headers': headers,
      });
    } catch (_) {
      // 锁屏媒体信息失败不影响视频播放。
    }
  }

  static Future<void> clear() async {
    if (!_supported) return;
    _onPlay = null;
    _onPause = null;
    _onToggle = null;
    _onSeek = null;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (_) {}
  }
}
