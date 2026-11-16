import 'dart:js_interop';

import 'package:web/web.dart' as web;

abstract final class HgPlayerDisplay {
  static Future<void> enterLandscape() async {
    try {
      final element = web.document.documentElement;
      if (element != null) {
        await element.requestFullscreen().toDart;
      }
    } catch (_) {}
    try {
      await web.window.screen.orientation.lock('landscape').toDart;
    } catch (_) {}
  }

  static Future<void> reset() async {
    try {
      web.window.screen.orientation.unlock();
    } catch (_) {}
    try {
      if (web.document.fullscreenElement != null) {
        await web.document.exitFullscreen().toDart;
      }
    } catch (_) {}
  }
}
