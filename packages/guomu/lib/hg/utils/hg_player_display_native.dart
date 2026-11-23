import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class HgPlayerDisplay {
  static const _landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  static Future<void> _pending = Future.value();

  @visibleForTesting
  static void resetQueueForTesting() => _pending = Future.value();

  static Future<void> enterAutoRotate() =>
      _apply([DeviceOrientation.portraitUp, ..._landscape]);

  static Future<void> enterLandscape() => _apply(_landscape);

  static Future<void> exitLandscape() => _apply([DeviceOrientation.portraitUp]);

  static Future<void> reset() =>
      _apply([DeviceOrientation.portraitUp], immersive: false);

  static Future<void> _apply(
    List<DeviceOrientation> orientations, {
    bool immersive = true,
  }) {
    return _pending = _pending.then((_) async {
      try {
        await SystemChrome.setPreferredOrientations(orientations);
        await SystemChrome.setEnabledSystemUIMode(
          immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
        );
      } catch (_) {}
    });
  }
}
