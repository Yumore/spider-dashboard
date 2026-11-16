import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._api, this._prefs) {
    _token = _prefs.getString(_tokenKey);
    _api.token = _token;
    final cachedUser = _prefs.getString(_userKey);
    if (cachedUser != null && cachedUser.isNotEmpty) {
      try {
        final user = HgUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(cachedUser) as Map),
        );
        _user = user;
        _favoriteIds = {...user.favoriteVideoIds};
        _likedEpisodes = {...user.likedEpisodes};
      } catch (_) {
        // 本地缓存损坏时忽略，随后通过 /account/me 重新同步。
      }
    }
  }

  static const _tokenKey = 'guomu.hg.token';
  static const _userKey = 'guomu.hg.user';

  final HgApi _api;
  final SharedPreferences _prefs;

  String? _token;
  HgUser? _user;
  Set<int> _favoriteIds = {};
  Set<String> _likedEpisodes = {};

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  HgUser? get user => _user;
  bool get isRestoring => _restoring;
  bool _restoring = false;

  Map<String, int> get counts => _user?.counts ?? const {};

  Future<void> restore() async {
    if (!isLoggedIn) return;
    _restoring = true;
    notifyListeners();
    try {
      _applyUser(await _api.me());
    } on HgLoginRequiredException {
      await _clearSession();
    } catch (_) {
      // 离线启动时保留已缓存账号，不把用户强制退出。
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    final session = await _api.login(username.trim(), password);
    await _setSession(session.token, session.user);
  }

  Future<void> register(
    String username,
    String password, {
    String email = '',
  }) async {
    final session = await _api.register(
      username.trim(),
      password,
      email: email,
    );
    await _setSession(session.token, session.user);
  }

  Future<void> refreshMe() async {
    if (!isLoggedIn) return;
    _applyUser(await _api.me());
    notifyListeners();
  }

  Future<void> updateProfile({
    required String nickname,
    required String sign,
    required String avatarColor,
  }) async {
    _ensureLoggedIn();
    final updated = await _api.updateProfile(
      nickname: nickname.trim(),
      sign: sign.trim(),
      avatarColor: avatarColor,
    );
    final favorites = {..._favoriteIds};
    final liked = {..._likedEpisodes};
    _user = HgUser(
      id: updated.id,
      username: updated.username,
      nickname: updated.nickname,
      avatar: updated.avatar,
      avatarColor: updated.avatarColor,
      sign: updated.sign,
      counts: updated.counts,
      favoriteVideoIds: favorites,
      likedEpisodes: liked,
      isFollowing: updated.isFollowing,
    );
    await _prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.logout();
    await _clearSession();
  }

  bool isFavorite(int videoId) => _favoriteIds.contains(videoId);

  bool isLiked(int videoId, int episode) {
    return _likedEpisodes.contains('$videoId:$episode');
  }

  Future<void> toggleFavorite(int videoId) async {
    _ensureLoggedIn();
    final wasFavorite = isFavorite(videoId);
    final next = !wasFavorite;
    if (next) {
      _favoriteIds.add(videoId);
    } else {
      _favoriteIds.remove(videoId);
    }
    notifyListeners();
    try {
      await _api.collect(videoId, next);
      await _persistUser();
    } catch (_) {
      if (wasFavorite) {
        _favoriteIds.add(videoId);
      } else {
        _favoriteIds.remove(videoId);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleLike(int videoId, int episode) async {
    _ensureLoggedIn();
    final key = '$videoId:$episode';
    final wasLiked = _likedEpisodes.contains(key);
    final next = !wasLiked;
    if (next) {
      _likedEpisodes.add(key);
    } else {
      _likedEpisodes.remove(key);
    }
    notifyListeners();
    try {
      await _api.like(videoId, episode, next);
      await _persistUser();
    } catch (_) {
      if (wasLiked) {
        _likedEpisodes.add(key);
      } else {
        _likedEpisodes.remove(key);
      }
      notifyListeners();
      rethrow;
    }
  }

  void _ensureLoggedIn() {
    if (!isLoggedIn) {
      throw const HgLoginRequiredException();
    }
  }

  Future<void> _setSession(String token, HgUser user) async {
    _token = token;
    _api.token = token;
    await _prefs.setString(_tokenKey, token);
    _applyUser(user);
    notifyListeners();
  }

  void _applyUser(HgUser user) {
    _user = user;
    _favoriteIds = {...user.favoriteVideoIds};
    _likedEpisodes = {...user.likedEpisodes};
  }

  Future<void> _persistUser() async {
    final current = _user;
    if (current == null) return;
    final updated = HgUser(
      id: current.id,
      username: current.username,
      nickname: current.nickname,
      avatar: current.avatar,
      avatarColor: current.avatarColor,
      sign: current.sign,
      counts: current.counts,
      favoriteVideoIds: {..._favoriteIds},
      likedEpisodes: {..._likedEpisodes},
      isFollowing: current.isFollowing,
    );
    _user = updated;
    await _prefs.setString(_userKey, jsonEncode(updated.toJson()));
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    _favoriteIds = {};
    _likedEpisodes = {};
    _api.token = null;
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
    notifyListeners();
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    final saved = _prefs.getString(_themeKey);
    _mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  static const _themeKey = 'guomu.theme';

  final SharedPreferences _prefs;
  late ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await _prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }
}

class SourceController extends ChangeNotifier {
  SourceController(this._prefs) {
    final rawSources = _prefs.getString(_sourcesKey);
    if (rawSources != null && rawSources.isNotEmpty) {
      try {
        final values = jsonDecode(rawSources);
        if (values is List) {
          _sources = values
              .map((value) => value.toString())
              .map(_safeNormalize)
              .whereType<String>()
              .toSet()
              .toList(growable: false);
        }
      } catch (_) {
        // 旧版本配置损坏时回退到默认源。
      }
    }
    if (_sources.isEmpty) {
      final saved = _prefs.getString(_sourceKey);
      if (saved != null && saved.isNotEmpty) {
        final normalized = _safeNormalize(saved);
        if (normalized != null) _sources = [normalized];
      }
    }
    if (_sources.isEmpty) _sources = [..._builtInSources];
    final savedActive = _prefs.getString(_activeKey);
    final active = _safeNormalize(savedActive);
    _baseUrl = active != null && _sources.contains(active)
        ? active
        : _sources.first;
  }

  static const _sourceKey = 'guomu.hg.source';
  static const _activeKey = 'guomu.hg.source.active';
  static const _sourcesKey = 'guomu.hg.sources.v2';
  static const _builtInSources = [
    kHgBootstrapBaseUrl,
    kHgDefaultBaseUrl,
    'https://2a52.bmikbxhi.cc',
    'https://0705.fvlelaqt.cc',
    'https://xe0av.bmikbxhi.cc',
  ];

  final SharedPreferences _prefs;
  late String _baseUrl;
  List<String> _sources = [];
  bool _discovering = false;
  bool _needsManual = false;
  bool _autoDiscoveryStarted = false;
  Timer? _discoveryTimer;

  String get baseUrl => _baseUrl;
  List<String> get sources => List.unmodifiable(_sources);
  bool get isDefault => _baseUrl == kHgDefaultBaseUrl;
  bool get isDiscovering => _discovering;
  bool get needsManual => _needsManual;

  Future<void> startAutoDiscovery() async {
    if (!_autoDiscoveryStarted) {
      _autoDiscoveryStarted = true;
      _discoveryTimer = Timer.periodic(const Duration(hours: 6), (_) {
        unawaited(startAutoDiscovery());
      });
    }
    if (_discovering) return;
    _discovering = true;
    notifyListeners();
    try {
      final discovered = await HgApi.discoverSources(
        seeds: [..._sources, ...await _bundledSources()],
      );
      await mergeDiscoveredSources(discovered);
      final candidates = <String>{
        _baseUrl,
        ...discovered,
        ..._sources,
      }.toList(growable: false);
      final probes = await Future.wait(
        candidates
            .take(8)
            .map(
              (candidate) async =>
                  (candidate, await HgApi.probeSource(candidate)),
            ),
      );
      for (final probe in probes) {
        if (probe.$2) {
          final candidate = probe.$1;
          if (_baseUrl != candidate) {
            _baseUrl = candidate;
            await _persist();
          }
          _needsManual = false;
          notifyListeners();
          return;
        }
      }
      _needsManual = true;
    } catch (_) {
      // 自动发现失败时保留内置源，不阻塞启动。
      _needsManual = true;
    } finally {
      _discovering = false;
      notifyListeners();
    }
  }

  Future<void> selectSource(String value) async {
    final normalized = _safeNormalize(value);
    if (normalized == null || !_sources.contains(normalized)) return;
    if (_baseUrl == normalized) return;
    _baseUrl = normalized;
    _needsManual = false;
    await _persist();
    notifyListeners();
  }

  Future<String> setBaseUrl(String value) async {
    final normalized = normalizeHgBaseUrl(value);
    if (!_sources.contains(normalized)) {
      _sources = [..._sources, normalized];
    }
    _baseUrl = normalized;
    _needsManual = false;
    await _persist();
    notifyListeners();
    return normalized;
  }

  Future<String> addSource(String value) async {
    final normalized = normalizeHgBaseUrl(value);
    if (!_sources.contains(normalized)) {
      _sources = [..._sources, normalized];
      await _persist();
      notifyListeners();
    }
    return normalized;
  }

  Future<void> removeSource(String value) async {
    final normalized = _safeNormalize(value);
    if (normalized == null || _sources.length <= 1) return;
    _sources = _sources.where((source) => source != normalized).toList();
    if (_baseUrl == normalized) _baseUrl = _sources.first;
    await _persist();
    notifyListeners();
  }

  Future<void> mergeDiscoveredSources(Iterable<String> values) async {
    final merged = <String>[..._sources];
    for (final value in values) {
      final normalized = _safeNormalize(value);
      if (normalized != null && !merged.contains(normalized)) {
        merged.add(normalized);
      }
    }
    if (merged.length == _sources.length) return;
    _sources = merged;
    if (!_sources.contains(_baseUrl)) _baseUrl = _sources.first;
    await _persist();
    notifyListeners();
  }

  Future<void> reset() async {
    if (_baseUrl == kHgDefaultBaseUrl) return;
    if (!_sources.contains(kHgDefaultBaseUrl)) {
      _sources = [kHgDefaultBaseUrl, ..._sources];
    }
    _baseUrl = kHgDefaultBaseUrl;
    _needsManual = false;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString(_sourcesKey, jsonEncode(_sources));
    await _prefs.setString(_activeKey, _baseUrl);
    await _prefs.setString(_sourceKey, _baseUrl);
  }

  Future<List<String>> _bundledSources() async {
    for (final assetPath in [
      'packages/guomu/assets/data/source_manifest.json',
      'assets/data/source_manifest.json',
    ]) {
      try {
        final raw = await rootBundle.loadString(assetPath);
        final value = jsonDecode(raw);
        if (value is! Map) continue;
        final sources = value['sources'];
        if (sources is! List) continue;
        return sources.map((item) => item.toString()).toList(growable: false);
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  static String? _safeNormalize(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return normalizeHgBaseUrl(value);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    super.dispose();
  }
}
