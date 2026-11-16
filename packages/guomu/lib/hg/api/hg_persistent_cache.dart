import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HgPersistentCache {
  HgPersistentCache(this._prefs);

  static const _prefix = 'guomu.content.cache.v1.';

  final SharedPreferences _prefs;

  List<String> get _keys => _prefs
      .getKeys()
      .where((key) => key.startsWith(_prefix))
      .toList(growable: false);

  Future<({Map<String, dynamic> data, DateTime? expiresAt})?> read(
    String key,
  ) async {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final wrapper = jsonDecode(raw);
      if (wrapper is! Map) return null;
      final data = wrapper['data'];
      if (data is! Map) return null;
      final expiresAtMs = (wrapper['expires_at'] as num?)?.toInt() ?? 0;
      return (
        data: Map<String, dynamic>.from(data),
        expiresAt: expiresAtMs <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
      );
    } catch (_) {
      await _prefs.remove('$_prefix$key');
      return null;
    }
  }

  Future<void> write(
    String key,
    Map<String, dynamic> data,
    Duration ttl,
  ) async {
    final wrapper = <String, dynamic>{
      'expires_at': DateTime.now().add(ttl).millisecondsSinceEpoch,
      'data': data,
    };
    await _prefs.setString('$_prefix$key', jsonEncode(wrapper));
  }

  Future<void> removePrefix(String prefix) async {
    for (final storedKey in _keys) {
      final key = storedKey.substring(_prefix.length);
      if (key.startsWith(prefix)) await _prefs.remove(storedKey);
    }
  }

  Future<void> remove(String key) async {
    await _prefs.remove('$_prefix$key');
  }

  Future<void> clearContent() async {
    for (final key in _keys) {
      await _prefs.remove(key);
    }
  }

  Future<int> sizeBytes() async {
    var bytes = 0;
    for (final key in _keys) {
      final value = _prefs.getString(key);
      if (value != null) bytes += utf8.encode(value).length;
    }
    return bytes;
  }
}
