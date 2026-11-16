import 'dart:js_interop';

@JS('guomuMediaCache.prefetchHls')
external JSPromise<JSAny?> _prefetchHls(JSString url, JSNumber segments);

@JS('guomuMediaCache.size')
external JSPromise<JSAny?> _size();

@JS('guomuMediaCache.clear')
external JSPromise<JSAny?> _clear();

abstract final class HgMediaCache {
  static Future<void> prefetchHls(String url, {int segments = 8}) async {
    if (url.isEmpty) return;
    try {
      await _prefetchHls(url.toJS, segments.toJS).toDart;
    } catch (_) {
      // 媒体预缓存失败不影响正常播放。
    }
  }

  static Future<int> sizeBytes() async {
    try {
      final value = await _size().toDart;
      return (value.dartify() as num?)?.round() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> clear() async {
    try {
      await _clear().toDart;
    } catch (_) {
      // 浏览器不支持 Cache API 时忽略。
    }
  }
}
