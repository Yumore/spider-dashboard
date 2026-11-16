abstract final class HgMediaCache {
  static Future<void> prefetchHls(String url, {int segments = 8}) async {}

  static Future<int> sizeBytes() async => 0;

  static Future<void> clear() async {}
}
