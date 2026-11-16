import 'package:flutter/services.dart';

abstract final class HgShare {
  static const _channel = MethodChannel('com.guomu.huangguo/share');

  static bool get canSystemShare => true;

  static Future<bool> shareText({
    required String title,
    required String text,
    required String url,
  }) async {
    try {
      final shared = await _channel.invokeMethod<bool>('share', {
        'title': title,
        'text': text,
        'url': url,
      });
      return shared ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
