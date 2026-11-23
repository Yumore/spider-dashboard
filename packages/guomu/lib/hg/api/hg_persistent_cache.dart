import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HgPersistentCache {
  HgPersistentCache(this._prefs);

  static const _v1Prefix = 'guomu.content.cache.v1.';
  static const _v2Prefix = 'guomu.content.cache.v2.';

  final SharedPreferences _prefs;

  List<String> _keysFor(String prefix) => _prefs
      .getKeys()
      .where((key) => key.startsWith(prefix))
      .toList(growable: false);

  Future<({Map<String, dynamic> data, DateTime? expiresAt})?> read(
    String key,
  ) async {
    final currentKey = '$_v2Prefix$key';
    final legacyKey = '$_v1Prefix$key';
    final raw = _prefs.getString(currentKey) ?? _prefs.getString(legacyKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final wrapper = jsonDecode(raw);
      if (wrapper is! Map) {
        await _removeBoth(key);
        return null;
      }
      final data = wrapper['data'];
      if (data is! Map) {
        await _removeBoth(key);
        return null;
      }
      final expiresAtMs = (wrapper['expires_at'] as num?)?.toInt() ?? 0;
      final expiresAt = expiresAtMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
      if (_prefs.containsKey(legacyKey) && !_prefs.containsKey(currentKey)) {
        if (expiresAt == null || expiresAt.isAfter(DateTime.now())) {
          await _writeRaw(
            currentKey,
            Map<String, dynamic>.from(data),
            expiresAt,
          );
        }
        await _prefs.remove(legacyKey);
      }
      return (data: Map<String, dynamic>.from(data), expiresAt: expiresAt);
    } catch (_) {
      await _removeBoth(key);
      return null;
    }
  }

  Future<void> write(
    String key,
    Map<String, dynamic> data,
    Duration ttl,
  ) async {
    final expiresAt = DateTime.now().add(ttl);
    await _writeRaw('$_v2Prefix$key', data, expiresAt);
  }

  Future<void> _writeRaw(
    String storageKey,
    Map<String, dynamic> data,
    DateTime? expiresAt,
  ) async {
    final wrapper = <String, dynamic>{
      'version': 2,
      'content_type': 'json',
      'expires_at': expiresAt?.millisecondsSinceEpoch ?? 0,
      'data': data,
    };
    await _prefs.setString(storageKey, jsonEncode(wrapper));
  }

  Future<void> removePrefix(String prefix) async {
    for (final storagePrefix in [_v1Prefix, _v2Prefix]) {
      for (final storedKey in _keysFor(storagePrefix)) {
        final key = storedKey.substring(storagePrefix.length);
        if (key.startsWith(prefix)) await _prefs.remove(storedKey);
      }
    }
  }

  Future<void> remove(String key) => _removeBoth(key);

  Future<void> _removeBoth(String key) async {
    await _prefs.remove('$_v1Prefix$key');
    await _prefs.remove('$_v2Prefix$key');
  }

  Future<void> clearContent() async {
    for (final storagePrefix in [_v1Prefix, _v2Prefix]) {
      for (final key in _keysFor(storagePrefix)) {
        await _prefs.remove(key);
      }
    }
  }

  Future<int> sizeBytes() async {
    var bytes = 0;
    for (final storagePrefix in [_v1Prefix, _v2Prefix]) {
      for (final storageKey in _keysFor(storagePrefix)) {
        final value = _prefs.getString(storageKey);
        if (value != null) bytes += utf8.encode(value).length;
      }
    }
    return bytes;
  }
}
