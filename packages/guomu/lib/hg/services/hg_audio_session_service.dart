import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Applies Guomu's playback audio session only while its embedded client is open.
abstract final class HgAudioSessionService {
  static const MethodChannel _channel = MethodChannel(
    'com.guomu.huangguo/audio',
  );

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> activate() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('activate');
    } on PlatformException {
      // Audio-session configuration must not block the Guomu client.
    } on MissingPluginException {
      // The integrated host may be running without the iOS bridge.
    }
  }

  static Future<void> deactivate() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('deactivate');
    } on PlatformException {
      // Audio-session restoration must not block Dashboard navigation.
    } on MissingPluginException {
      // The integrated host may be running without the iOS bridge.
    }
  }
}
