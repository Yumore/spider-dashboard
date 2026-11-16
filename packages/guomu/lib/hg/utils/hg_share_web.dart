import 'dart:js_interop';

import 'package:web/web.dart' as web;

abstract final class HgShare {
  static bool get canSystemShare {
    try {
      return web.window.navigator.canShare(web.ShareData(title: '果幕 · 黄果短剧'));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> shareText({
    required String title,
    required String text,
    required String url,
  }) async {
    try {
      final data = web.ShareData(title: title, text: text, url: url);
      if (!web.window.navigator.canShare(data)) return false;
      await web.window.navigator.share(data).toDart;
      return true;
    } catch (_) {
      return false;
    }
  }
}
