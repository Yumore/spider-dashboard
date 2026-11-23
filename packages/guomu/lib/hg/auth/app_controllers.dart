import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/hg_api.dart';
import '../api/hg_source_pool.dart';
import '../models/hg_models.dart';

class AuthController extends ChangeNotifier with WidgetsBindingObserver {
  AuthController(this._api, this._prefs) {
    _token = _prefs.getString(_tokenKey);
    _api.token = _token;
    _api.onAuthenticationExpired = _handleAuthenticationExpired;
    WidgetsBinding.instance.addObserver(this);
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
  Future<void>? _sessionExpiration;

  Map<String, int> get counts => _user?.counts ?? const {};

  Future<void> restore() async {
    if (!isLoggedIn || _restoring) return;
    _restoring = true;
    notifyListeners();
    try {
      _applyUser(await _api.me());
    } on HgLoginRequiredException {
      await expireSession();
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
    try {
      _applyUser(await _api.me());
      notifyListeners();
    } on HgLoginRequiredException {
      await expireSession();
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String nickname,
    required String sign,
    required String avatarColor,
  }) async {
    _ensureLoggedIn();
    late final HgUser updated;
    try {
      updated = await _api.updateProfile(
        nickname: nickname.trim(),
        sign: sign.trim(),
        avatarColor: avatarColor,
      );
    } on HgLoginRequiredException {
      await expireSession();
      rethrow;
    }
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
    await expireSession();
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
    } on HgLoginRequiredException {
      if (wasFavorite) {
        _favoriteIds.add(videoId);
      } else {
        _favoriteIds.remove(videoId);
      }
      notifyListeners();
      await expireSession();
      rethrow;
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
    } on HgLoginRequiredException {
      if (wasLiked) {
        _likedEpisodes.add(key);
      } else {
        _likedEpisodes.remove(key);
      }
      notifyListeners();
      await expireSession();
      rethrow;
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
    final pendingExpiration = _sessionExpiration;
    if (pendingExpiration != null) await pendingExpiration;
    _token = token;
    _api.token = token;
    await _prefs.setString(_tokenKey, token);
    _applyUser(user);
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
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

  void _handleAuthenticationExpired() {
    unawaited(expireSession());
  }

  /// Clears a rejected session once and lets callers await the same cleanup.
  Future<void> expireSession() {
    final active = _sessionExpiration;
    if (active != null) return active;
    if (_token == null && _user == null) return Future<void>.value();
    late final Future<void> expiration;
    expiration = _clearSession().whenComplete(() {
      if (identical(_sessionExpiration, expiration)) {
        _sessionExpiration = null;
      }
    });
    _sessionExpiration = expiration;
    return expiration;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isLoggedIn) {
      unawaited(restore());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _api.onAuthenticationExpired = null;
    super.dispose();
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

class SourceController extends ChangeNotifier
    with WidgetsBindingObserver
    implements HgSourceRouter {
  SourceController(
    this._prefs, {
    Future<HgSourceProbeResult> Function(String source)? probeSource,
  }) : _probeSource = probeSource ?? HgApi.probeSource {
    _pool = _restorePool();
    if (_pool.automaticSelection) _pool.selectBestAvailable();
    _lastDiscoveryAt = _dateFromMilliseconds(_prefs.getInt(_lastDiscoveryKey));
    _syncRuntimeBaseUrl();
    WidgetsBinding.instance.addObserver(this);
  }

  static const _sourceKey = 'guomu.hg.source';
  static const _activeKey = 'guomu.hg.source.active';
  static const _sourcesKey = 'guomu.hg.sources.v3';
  static const _legacySourcesKey = 'guomu.hg.sources.v2';
  static const _lastDiscoveryKey = 'guomu.hg.sources.lastDiscoveryAt';
  static const _builtInSources = [
    kHgBootstrapBaseUrl,
    kHgDefaultBaseUrl,
    'https://2a52.bmikbxhi.cc',
    'https://0705.fvlelaqt.cc',
    'https://xe0av.bmikbxhi.cc',
  ];

  final SharedPreferences _prefs;
  final Future<HgSourceProbeResult> Function(String source) _probeSource;
  late HgSourcePool _pool;
  bool _discovering = false;
  bool _probing = false;
  bool _needsManual = false;
  bool _autoDiscoveryStarted = false;
  Timer? _discoveryTimer;
  Timer? _healthPersistTimer;
  DateTime? _lastDiscoveryAt;

  HgSourcePool get pool => _pool;

  @override
  String get baseUrl => _pool.baseUrl;

  @override
  List<String> get rankedSources => _pool.rankedSources;

  List<String> get sources => _pool.sources;
  List<HgSourceHealth> get sourceHealth => _pool.health;
  bool get automaticSelection => _pool.automaticSelection;
  bool get isDefault => baseUrl == kHgDefaultBaseUrl;
  bool get isDiscovering => _discovering;
  bool get isProbing => _probing;
  bool get needsManual => _needsManual;

  Future<void> startAutoDiscovery({bool force = false}) async {
    if (!_autoDiscoveryStarted) {
      _autoDiscoveryStarted = true;
      _discoveryTimer = Timer.periodic(const Duration(hours: 6), (_) {
        unawaited(startAutoDiscovery());
      });
    }
    if (_discovering) return;
    if (!force &&
        _lastDiscoveryAt != null &&
        DateTime.now().difference(_lastDiscoveryAt!) <
            const Duration(minutes: 30)) {
      return;
    }
    _discovering = true;
    notifyListeners();
    try {
      final discovered = await HgApi.discoverSources(
        seeds: [...sources, ...await _bundledSources()],
      );
      await mergeDiscoveredSources(discovered);
      final candidates = <String>{
        ...sources,
        ...discovered,
      }.toList(growable: false);
      await _probeCandidates(candidates);
      final best = _pool.selectBestAvailable();
      _needsManual = best == null;
      if (best != null) _syncRuntimeBaseUrl();
      _lastDiscoveryAt = DateTime.now();
      await _persist();
    } catch (_) {
      // 自动发现失败时保留内置源，不阻塞启动。
      _needsManual = _pool.health.every((item) => item.isCoolingDown);
    } finally {
      _discovering = false;
      notifyListeners();
    }
  }

  Future<void> selectSource(String value) async {
    final normalized = _safeNormalize(value);
    if (normalized == null || !sources.contains(normalized)) return;
    if (baseUrl == normalized) return;
    _pool.setActive(normalized);
    _needsManual = false;
    _syncRuntimeBaseUrl();
    await _persist();
    notifyListeners();
  }

  Future<String> setBaseUrl(String value) async {
    final normalized = normalizeHgBaseUrl(value);
    _pool.merge([normalized]);
    _pool.setActive(normalized);
    _needsManual = false;
    _syncRuntimeBaseUrl();
    await _persist();
    notifyListeners();
    return normalized;
  }

  Future<String> addSource(String value) async {
    final normalized = normalizeHgBaseUrl(value);
    final probe = await _probeSource(normalized);
    if (!probe.available) {
      throw HgApiException(probe.error ?? '该地址未返回有效的黄果短剧接口');
    }
    _pool.merge([normalized]);
    await _pool.recordSuccess(
      normalized,
      probe.latency ?? const Duration(seconds: 3),
      promote: false,
    );
    await _persist();
    notifyListeners();
    return normalized;
  }

  Future<void> removeSource(String value) async {
    final normalized = _safeNormalize(value);
    if (normalized == null || sources.length <= 1) return;
    _pool.remove(normalized);
    _syncRuntimeBaseUrl();
    await _persist();
    notifyListeners();
  }

  Future<void> mergeDiscoveredSources(Iterable<String> values) async {
    final normalizedValues = <String>[];
    for (final value in values) {
      final normalized = _safeNormalize(value);
      if (normalized != null) normalizedValues.add(normalized);
    }
    final before = sources.length;
    _pool.merge(normalizedValues);
    if (sources.length == before) return;
    await _persist();
    notifyListeners();
  }

  Future<void> setAutomaticSelection(bool value) async {
    if (_pool.automaticSelection == value) return;
    _pool.setAutomaticSelection(value);
    if (value) _pool.selectBestAvailable();
    _syncRuntimeBaseUrl();
    await _persist();
    notifyListeners();
  }

  Future<void> refreshSourceHealth() async {
    await probeSources();
  }

  Future<void> probeSources() async {
    if (_probing || _discovering) return;
    _probing = true;
    notifyListeners();
    try {
      await _probeCandidates(sources);
      final best = _pool.selectBestAvailable();
      _needsManual = best == null;
      if (best != null) _syncRuntimeBaseUrl();
      await _persist();
    } finally {
      _probing = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(startAutoDiscovery());
    }
  }

  @override
  Future<void> recordSuccess(
    String source,
    Duration latency, {
    required bool promote,
  }) async {
    final previous = baseUrl;
    await _pool.recordSuccess(source, latency, promote: promote);
    _syncRuntimeBaseUrl();
    _scheduleHealthPersist();
    if (previous != baseUrl) notifyListeners();
  }

  @override
  Future<void> recordFailure(String source) async {
    final previous = baseUrl;
    await _pool.recordFailure(source);
    _syncRuntimeBaseUrl();
    _scheduleHealthPersist();
    if (previous != baseUrl) notifyListeners();
  }

  Future<void> reset() async {
    if (baseUrl == kHgDefaultBaseUrl) return;
    _pool.resetTo(kHgDefaultBaseUrl);
    _needsManual = false;
    _syncRuntimeBaseUrl();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString(_sourcesKey, jsonEncode(_pool.toJson()));
    await _prefs.setString(_activeKey, baseUrl);
    await _prefs.setString(_sourceKey, baseUrl);
    if (_lastDiscoveryAt != null) {
      await _prefs.setInt(
        _lastDiscoveryKey,
        _lastDiscoveryAt!.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _probeCandidates(Iterable<String> values) async {
    final candidates = values
        .map(_safeNormalize)
        .whereType<String>()
        .toSet()
        .take(12)
        .toList(growable: false);
    for (var index = 0; index < candidates.length; index += 4) {
      final probes = await Future.wait(
        candidates.skip(index).take(4).map(_probeSource),
      );
      for (final probe in probes) {
        if (probe.available) {
          await _pool.recordSuccess(
            probe.baseUrl,
            probe.latency ?? const Duration(seconds: 3),
            promote: false,
          );
        } else {
          await _pool.recordFailure(probe.baseUrl);
        }
      }
    }
  }

  void _scheduleHealthPersist() {
    _healthPersistTimer?.cancel();
    _healthPersistTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_persist());
    });
  }

  HgSourcePool _restorePool() {
    final raw = _prefs.getString(_sourcesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final value = jsonDecode(raw);
        if (value is Map) {
          final pool = HgSourcePool.fromJson(
            Map<String, dynamic>.from(value),
            fallbackSources: _builtInSources,
          );
          if (pool.sources.isNotEmpty) return pool;
        }
      } catch (_) {
        // 新版源池损坏时继续尝试兼容旧版本列表。
      }
    }

    final legacy = <String>[];
    final rawLegacy = _prefs.getString(_legacySourcesKey);
    if (rawLegacy != null && rawLegacy.isNotEmpty) {
      try {
        final values = jsonDecode(rawLegacy);
        if (values is List) legacy.addAll(values.map((item) => '$item'));
      } catch (_) {}
    }
    final saved = _prefs.getString(_sourceKey);
    if (saved != null && saved.isNotEmpty) legacy.add(saved);
    final sources = <String>[];
    for (final value in [...legacy, ..._builtInSources]) {
      final normalized = _safeNormalize(value);
      if (normalized != null && !sources.contains(normalized)) {
        sources.add(normalized);
      }
    }
    final active = _safeNormalize(_prefs.getString(_activeKey));
    return HgSourcePool(sources: sources, activeSource: active);
  }

  void _syncRuntimeBaseUrl() {
    if (baseUrl.isNotEmpty) HgRuntimeConfig.setBaseUrl(baseUrl);
  }

  static DateTime? _dateFromMilliseconds(int? value) {
    if (value == null || value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
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
    WidgetsBinding.instance.removeObserver(this);
    _discoveryTimer?.cancel();
    _healthPersistTimer?.cancel();
    super.dispose();
  }
}
