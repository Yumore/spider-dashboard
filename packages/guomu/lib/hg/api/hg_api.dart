import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'hg_persistent_cache.dart';

import '../models/hg_models.dart';

const String kHgDefaultBaseUrl = 'https://huangguoai.com';
const String kHgBootstrapBaseUrl = 'https://2a52.bmikbxhi.cc';
const String _configuredBaseUrl = String.fromEnvironment('HG_API_BASE');
const String _configuredWebProxyUrl = String.fromEnvironment(
  'HG_WEB_PROXY_URL',
);
const String kHgUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

String normalizeHgBaseUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    throw const FormatException('请输入黄果源地址');
  }
  if (!value.contains('://')) value = 'https://$value';
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw const FormatException('地址格式无效，请填写 http(s) 域名');
  }
  if (uri.userInfo.isNotEmpty) {
    throw const FormatException('黄果源地址不能包含账号或密码');
  }
  return uri.origin;
}

abstract final class HgRuntimeConfig {
  static String _baseUrl = _configuredBaseUrl.isEmpty
      ? kHgDefaultBaseUrl
      : normalizeHgBaseUrl(_configuredBaseUrl);

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String value) {
    _baseUrl = normalizeHgBaseUrl(value);
  }
}

String resolveHgApiBaseUrl() => HgRuntimeConfig.baseUrl;

Map<String, String> hgMediaHeadersFor(String baseUrl) => {
  if (!kIsWeb) 'User-Agent': kHgUserAgent,
  if (!kIsWeb) 'Referer': '${normalizeHgBaseUrl(baseUrl)}/',
};

Map<String, String> hgMediaHeaders() =>
    hgMediaHeadersFor(HgRuntimeConfig.baseUrl);

class HgApiException implements Exception {
  const HgApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HgLoginRequiredException extends HgApiException {
  const HgLoginRequiredException([super.message = '请先登录']);
}

class _CacheEntry<T> {
  const _CacheEntry(this.value, this.expiresAt);

  final Future<T> value;
  final DateTime expiresAt;
}

class HgApi {
  HgApi({String? baseUrl, Dio? dio, SharedPreferences? preferences})
    : _persistentCache = preferences == null
          ? null
          : HgPersistentCache(preferences),
      _dio = dio ?? _createDio(baseUrl ?? HgRuntimeConfig.baseUrl) {
    if (dio == null) HgRuntimeConfig.setBaseUrl(_dio.options.baseUrl);
    // 旧版本曾把短时播放地址持久化 12 小时；启动时清理，避免继续使用过期票据。
    final persistent = _persistentCache;
    if (persistent != null) unawaited(persistent.removePrefix('playback:'));
  }

  final Dio _dio;
  final HgPersistentCache? _persistentCache;
  String? token;
  final Map<String, _CacheEntry<Map<String, dynamic>>> _rawCache = {};
  final Map<String, Future<Map<String, dynamic>>> _rawRefreshing = {};
  final Map<String, _CacheEntry<List<HgRankItem>>> _rankCache = {};

  String get baseUrl => _dio.options.baseUrl;

  static Future<void> probeBaseUrl(String value) async {
    final normalized = normalizeHgBaseUrl(value);
    final dio = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 12),
        headers: {
          'Accept': 'application/json',
          ...hgMediaHeadersFor(normalized),
        },
      ),
    );
    final api = HgApi(dio: dio);
    final page = await api.feed(size: 1);
    if (page.items.isEmpty) {
      throw const HgApiException('源已连接，但没有返回短剧数据');
    }
  }

  void setBaseUrl(String value) {
    final normalized = normalizeHgBaseUrl(value);
    if (_dio.options.baseUrl == normalized) return;
    HgRuntimeConfig.setBaseUrl(normalized);
    _dio.options.baseUrl = normalized;
    if (!kIsWeb) {
      _dio.options.headers['Referer'] = '$normalized/';
    }
    _clearContentCaches();
  }

  void _clearContentCaches() {
    _rawCache.clear();
    _rawRefreshing.clear();
    _rankCache.clear();
    final persistent = _persistentCache;
    if (persistent != null) unawaited(persistent.clearContent());
  }

  Future<Map<String, dynamic>> _cachedData(
    String key,
    Duration ttl,
    Future<dynamic> Function() load,
  ) async {
    final now = DateTime.now();
    final memory = _rawCache[key];
    if (memory != null && memory.expiresAt.isAfter(now)) {
      return memory.value;
    }

    final persisted = await _persistentCache?.read(key);
    if (persisted != null) {
      final expiresAt = persisted.expiresAt;
      if (expiresAt == null || expiresAt.isAfter(now)) {
        final value = Future<Map<String, dynamic>>.value(persisted.data);
        _rawCache[key] = _CacheEntry(value, expiresAt ?? now.add(ttl));
        return persisted.data;
      }
      unawaited(
        _refreshData(key, ttl, load).then<void>((_) {}, onError: (Object _) {}),
      );
      return persisted.data;
    }
    return _refreshData(key, ttl, load);
  }

  Future<Map<String, dynamic>> _refreshData(
    String key,
    Duration ttl,
    Future<dynamic> Function() load,
  ) {
    final active = _rawRefreshing[key];
    if (active != null) return active;
    final future = () async {
      final data = asMap(await load());
      _rawCache[key] = _CacheEntry(
        Future<Map<String, dynamic>>.value(data),
        DateTime.now().add(ttl),
      );
      await _persistentCache?.write(key, data, ttl);
      return data;
    }();
    _rawRefreshing[key] = future;
    future.whenComplete(() => _rawRefreshing.remove(key));
    return future;
  }

  void _invalidateData(String key) {
    _rawCache.remove(key);
    final persistent = _persistentCache;
    if (persistent != null) unawaited(persistent.remove(key));
  }

  void _invalidateDataPrefix(String prefix) {
    final keys = _rawCache.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      _rawCache.remove(key);
    }
    final persistent = _persistentCache;
    if (persistent != null) unawaited(persistent.removePrefix(prefix));
  }

  Future<int> cacheSizeBytes() async =>
      await _persistentCache?.sizeBytes() ?? 0;

  Future<void> clearContentCache() async {
    _clearContentCaches();
    await _persistentCache?.clearContent();
  }

  Future<T> _cached<T>(
    Map<String, _CacheEntry<T>> cache,
    String key,
    Duration ttl,
    Future<T> Function() load,
  ) {
    final now = DateTime.now();
    final existing = cache[key];
    if (existing != null && existing.expiresAt.isAfter(now)) {
      return existing.value;
    }
    final value = load();
    cache[key] = _CacheEntry(value, now.add(ttl));
    value.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(cache[key]?.value, value)) cache.remove(key);
      },
    );
    return value;
  }

  static Dio _createDio(String baseUrl) {
    HgRuntimeConfig.setBaseUrl(baseUrl);
    return Dio(
      BaseOptions(
        baseUrl: HgRuntimeConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json', ...hgMediaHeaders()},
      ),
    );
  }

  Future<({String token, HgUser user})> login(
    String username,
    String password,
  ) async {
    final data = asMap(
      await _request(
        'POST',
        '/api/account/loginByPassword',
        body: {'username': username, 'password': password},
      ),
    );
    return _sessionFromData(data);
  }

  Future<({String token, HgUser user})> register(
    String username,
    String password, {
    String email = '',
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'password': password,
      'confirm_password': password,
    };
    if (email.trim().isNotEmpty) body['email'] = email.trim();
    final data = asMap(
      await _request('POST', '/api/account/registerByPassword', body: body),
    );
    return _sessionFromData(data);
  }

  Future<void> logout() async {
    if (token == null) return;
    try {
      await _request('POST', '/api/account/logout');
    } catch (_) {
      // 本地会话仍需清理，服务端退出失败不阻塞用户。
    }
  }

  Future<HgUser> updateProfile({
    required String nickname,
    required String sign,
    required String avatarColor,
  }) async {
    return HgUser.fromJson(
      asMap(
        await _request(
          'PATCH',
          '/api/account/profile',
          body: {
            'nickname': nickname,
            'sign': sign,
            'avatar_color': avatarColor,
          },
        ),
      ),
    );
  }

  Future<HgUser> me() async {
    return HgUser.fromJson(asMap(await _request('GET', '/api/account/me')));
  }

  Future<HgPage<HgVideoCard>> feed({
    int page = 1,
    int size = 20,
    String sort = '',
  }) async {
    final sortQuery = sort.isEmpty
        ? ''
        : '&sort=${Uri.encodeQueryComponent(sort)}';
    final key = 'feed:$page:$size:$sort';
    final data = await _cachedData(
      key,
      const Duration(hours: 12),
      () => _request('GET', '/api/videos?page=$page&size=$size$sortQuery'),
    );
    return HgPage.fromJson(data, HgVideoCard.fromJson);
  }

  Future<HgHomeData> home() async {
    final data = await _cachedData(
      'home:overview',
      const Duration(minutes: 30),
      () => _request('GET', '/api/home'),
    );
    return HgHomeData.fromJson(data);
  }

  Future<List<HgVideoCard>> homeRecommendations({int size = 20}) async {
    return (await homeRecommendationsPage(size: size)).items;
  }

  Future<HgPage<HgVideoCard>> homeRecommendationsPage({
    int page = 1,
    int size = 20,
  }) async {
    final data = await _cachedData(
      'home:recommends:$page:$size',
      const Duration(hours: 12),
      () => _request('GET', '/api/home/recommends?page=$page&size=$size'),
    );
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => HgVideoCard.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id > 0)
              .toList(growable: false)
        : const <HgVideoCard>[];
    final currentPage = asInt(data['page'], fallback: page);
    final pageSize = asInt(data['size'], fallback: size);
    final total = asInt(data['total']);
    final pages = pageSize <= 0 ? 1 : (total / pageSize).ceil().clamp(1, 9999);
    return HgPage(
      items: items,
      pagination: HgPagination(
        page: currentPage,
        pages: pages,
        size: pageSize,
        total: total,
      ),
    );
  }

  Future<List<HgVideoCategory>> videoCategories() async {
    final data = await _cachedData(
      'video:categories',
      const Duration(hours: 24),
      () => _request('GET', '/api/site/categories/video'),
    );
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map(
          (item) => HgVideoCategory.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.route.isNotEmpty)
        .toList(growable: false);
  }

  Future<HgTagDirectory> tagDirectory() async {
    final data = await _cachedData(
      'video:tags',
      const Duration(hours: 12),
      () => _request('GET', '/api/tags'),
    );
    return HgTagDirectory.fromJson(data);
  }

  Future<HgPage<HgVideoCard>> videosByTag(
    String tag, {
    int page = 1,
    int size = 20,
  }) async {
    final encoded = Uri.encodeComponent(tag.trim());
    final data = await _cachedData(
      'video:tag:$encoded:$page:$size',
      const Duration(hours: 12),
      () => _request('GET', '/api/videos/tag/$encoded?page=$page&size=$size'),
    );
    return HgPage.fromJson(data, HgVideoCard.fromJson);
  }

  Future<HgPage<HgVideoCard>> category(
    String category, {
    int page = 1,
    int size = 20,
    String sort = '',
  }) async {
    final encoded = Uri.encodeComponent(category);
    final sortQuery = sort.isEmpty
        ? ''
        : '&sort=${Uri.encodeQueryComponent(sort)}';
    final key = 'category:$encoded:$page:$size:$sort';
    final data = await _cachedData(
      key,
      const Duration(hours: 12),
      () => _request(
        'GET',
        '/api/videos/category/$encoded?page=$page&size=$size$sortQuery',
      ),
    );
    return HgPage.fromJson(data, HgVideoCard.fromJson);
  }

  Future<List<HgRankItem>> rank(String kind) async {
    final safeKind = switch (kind) {
      'recommend' => 'recommend',
      'potential' => 'potential',
      _ => 'hot',
    };
    return _cached(_rankCache, safeKind, const Duration(minutes: 10), () async {
      final data = asMap(await _request('GET', '/api/ranks/$safeKind'));
      final items = data['items'];
      if (items is! List) return const <HgRankItem>[];
      return items
          .whereType<Map>()
          .map((item) => HgRankItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  Future<List<String>> hotSearchWords() async {
    final data = asMap(await _request('GET', '/api/search/hot'));
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => asText(item['word'] ?? item['name']))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> hotSearchTags() async {
    final data = asMap(await _request('GET', '/api/search/tags/hot'));
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => asText(item['name'] ?? item['word']))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> searchSuggestions(String keyword) async {
    final q = Uri.encodeQueryComponent(keyword.trim());
    if (q.isEmpty) return const [];
    final data = asMap(await _request('GET', '/api/search/suggest?q=$q'));
    for (final key in const ['items', 'phrases', 'tags', 'content']) {
      final values = data[key];
      if (values is List) {
        final words = values
            .map(asText)
            .where((word) => word.isNotEmpty)
            .toList();
        if (words.isNotEmpty) return words;
      }
    }
    return const [];
  }

  Future<HgPage<HgVideoCard>> search(
    String keyword, {
    int page = 1,
    int size = 20,
  }) async {
    final q = Uri.encodeQueryComponent(keyword.trim());
    final data = await _request(
      'GET',
      '/api/search?q=$q&page=$page&size=$size',
    );
    return HgPage.fromJson(asMap(data), HgVideoCard.fromJson);
  }

  Future<HgPage<HgPost>> posts({int page = 1, int size = 20}) async {
    final data = await _cachedData(
      'posts:all:$page:$size',
      const Duration(hours: 12),
      () => _request('GET', '/api/posts?page=$page&size=$size'),
    );
    return HgPage.fromJson(data, HgPost.fromJson);
  }

  Future<HgPage<HgPost>> postsByCategory(
    String route, {
    int page = 1,
    int size = 20,
  }) async {
    final encoded = Uri.encodeComponent(route);
    final data = await _cachedData(
      'posts:category:$encoded:$page:$size',
      const Duration(hours: 12),
      () =>
          _request('GET', '/api/posts/category/$encoded?page=$page&size=$size'),
    );
    return HgPage.fromJson(data, HgPost.fromJson);
  }

  Future<HgPage<HgPost>> postsByTag(
    String tag, {
    int page = 1,
    int size = 20,
  }) async {
    final encoded = Uri.encodeComponent(tag);
    final data = await _cachedData(
      'posts:tag:$encoded:$page:$size',
      const Duration(hours: 12),
      () => _request('GET', '/api/posts/tag/$encoded?page=$page&size=$size'),
    );
    return HgPage.fromJson(data, HgPost.fromJson);
  }

  Future<HgPostDetail> post(int id) async {
    final data = await _cachedData(
      'post:$id',
      const Duration(hours: 24),
      () => _request('GET', '/api/posts/$id'),
    );
    return HgPostDetail.fromJson(data);
  }

  Future<HgPostAdjacent> postAdjacent(int id) async {
    return HgPostAdjacent.fromJson(
      asMap(await _request('GET', '/api/posts/$id/adjacent')),
    );
  }

  Future<HgPage<HgPost>> postRelated(
    int id, {
    int page = 1,
    int size = 12,
  }) async {
    final data = await _request(
      'GET',
      '/api/posts/$id/related?page=$page&size=$size',
    );
    return HgPage.fromJson(asMap(data), HgPost.fromJson);
  }

  Future<HgPostPlayback> postPlayback(int id) async {
    final data = await _cachedData(
      'post-playback:$id',
      const Duration(hours: 12),
      () => _request(
        'POST',
        '/api/posts/$id/playback',
        body: const <String, dynamic>{},
      ),
    );
    return HgPostPlayback.fromJson(data);
  }

  Future<HgCommentPage> postComments(
    int id, {
    int page = 1,
    int size = 30,
  }) async {
    final data = await _cachedData(
      'post-comments:$id:$page:$size',
      const Duration(minutes: 3),
      () => _request('GET', '/api/posts/$id/comments?page=$page&size=$size'),
    );
    return HgCommentPage.fromJson(data);
  }

  Future<void> sendPostComment(int id, String text) async {
    await _request('POST', '/api/posts/$id/comments', body: {'text': text});
    _invalidateDataPrefix('post-comments:$id:');
  }

  Future<void> likePostComment(int postId, int commentId, bool on) async {
    await _request(
      on ? 'POST' : 'DELETE',
      '/api/posts/$postId/comments/$commentId/like',
    );
    _invalidateDataPrefix('post-comments:$postId:');
  }

  Future<void> likePost(int id, bool on) async {
    await _request(on ? 'POST' : 'DELETE', '/api/posts/$id/like');
    _invalidateData('post:$id');
  }

  Future<void> collectPost(int id, bool on) async {
    await _request(on ? 'POST' : 'DELETE', '/api/posts/$id/collect');
    _invalidateData('post:$id');
  }

  Future<HgPage<HgTopic>> topics({int page = 1, int size = 12}) async {
    final data = await _cachedData(
      'topics:$page:$size',
      const Duration(hours: 24),
      () => _request('GET', '/api/topics?page=$page&size=$size'),
    );
    return HgPage.fromJson(data, HgTopic.fromJson);
  }

  Future<HgTopicDetail> topic(
    String slug, {
    int page = 1,
    int size = 20,
  }) async {
    final encoded = Uri.encodeComponent(slug);
    final data = await _cachedData(
      'topic:$encoded:$page:$size',
      const Duration(hours: 24),
      () => _request('GET', '/api/topics/$encoded?page=$page&size=$size'),
    );
    return HgTopicDetail.fromJson(data);
  }

  Future<HgVideoDetail> video(int id) async {
    final data = await _cachedData(
      'video:$id',
      const Duration(hours: 24),
      () => _request('GET', '/api/videos/$id'),
    );
    return HgVideoDetail.fromJson(data);
  }

  Future<HgPlayInfo> playback(int videoId, int episode) async {
    // 播放地址含 CDN 临时鉴权参数，不能写入 12 小时持久化缓存；
    // 切集/重试时始终获取新的播放票据，避免旧 URL 触发 Source error。
    final data = asMap(
      await _request(
        'POST',
        '/api/videos/$videoId/episodes/$episode/playback',
        body: const <String, dynamic>{},
      ),
    );
    final info = HgPlayInfo.fromJson(data, videoId: videoId, episode: episode);
    if (info.videoUrl.isEmpty) {
      throw const HgApiException('暂无播放地址，请稍后再试');
    }
    return info;
  }

  Future<HgCommentPage> comments(
    int videoId,
    int episode, {
    int page = 1,
    int size = 20,
  }) async {
    final data = await _cachedData(
      'comments:$videoId:$episode:$page:$size',
      const Duration(minutes: 3),
      () => _request(
        'GET',
        '/api/videos/$videoId/comments?ep=$episode&page=$page&size=$size',
      ),
    );
    return HgCommentPage.fromJson(data);
  }

  void warmStartup() {
    unawaited(_warmStartup());
  }

  Future<void> _warmStartup() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      final homeFuture = home();
      final feedPageFuture = feed(size: 24);
      final feedPage = await feedPageFuture;
      await homeFuture;

      // 首屏先完成图片解码与滚动输入，再启动低优先级的专题/文章/详情预热。
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final topicFuture = topics(size: 30);
      final postFuture = posts(size: 24);
      final categoryFuture = videoCategories();
      final tagsFuture = tagDirectory();
      final newestFuture = feed(size: 12, sort: 'new');
      final hotRankFuture = rank('hot');
      final recommendRankFuture = rank('recommend');
      final potentialRankFuture = rank('potential');
      final dramaFuture = category('ai-duanju', size: 30, sort: 'new');
      final manjuFuture = category('ai-manju', size: 30, sort: 'new');
      final gossipFuture = postsByCategory('remen-chigua', size: 24);
      final reviewFuture = postsByTag('黄果原创', size: 24);
      final recommendationsFuture = homeRecommendationsPage(size: 20);
      final hotWordsFuture = hotSearchWords();
      final hotTagsFuture = hotSearchTags();
      final topicPage = await topicFuture;
      final postPage = await postFuture;
      await categoryFuture;
      await tagsFuture;
      final newest = await newestFuture;
      await hotRankFuture;
      await recommendRankFuture;
      await potentialRankFuture;
      final drama = await dramaFuture;
      final manju = await manjuFuture;
      await gossipFuture;
      await reviewFuture;
      await recommendationsFuture;
      await hotWordsFuture;
      await hotTagsFuture;
      await Future.wait<void>([
        prefetchVideoDetails(
          [
            ...feedPage.items.take(6),
            ...newest.items.take(6),
            ...drama.items.take(4),
            ...manju.items.take(4),
          ].map((item) => item.id),
        ),
        _prefetchPostDetails(postPage.items.take(3).map((item) => item.id)),
        _prefetchTopicDetails(topicPage.items.take(3).map((item) => item.slug)),
      ]);
      // 启动阶段只预热元数据，不在用户尚未进入播放器时预取 HLS 分片。
    } catch (_) {
      // 启动预热失败不影响正常浏览。
    }
  }

  Future<void> _prefetchPostDetails(Iterable<int> ids) async {
    final queue = ids.toSet().toList(growable: false);
    for (var index = 0; index < queue.length; index += 3) {
      await Future.wait(
        queue
            .skip(index)
            .take(3)
            .map((id) => post(id).then<void>((_) {}, onError: (Object _) {})),
      );
    }
  }

  Future<void> _prefetchTopicDetails(Iterable<String> slugs) async {
    final queue = slugs.where((slug) => slug.isNotEmpty).toSet().toList();
    for (var index = 0; index < queue.length; index += 2) {
      await Future.wait(
        queue
            .skip(index)
            .take(2)
            .map(
              (slug) => topic(slug).then<void>((_) {}, onError: (Object _) {}),
            ),
      );
    }
  }

  Future<void> prefetchVideoDetails(Iterable<int> ids, {int limit = 6}) async {
    final queue = ids.take(limit).toSet().toList(growable: false);
    for (var index = 0; index < queue.length; index += 3) {
      final chunk = queue.skip(index).take(3);
      await Future.wait(
        chunk.map((id) => video(id).then<void>((_) {}, onError: (Object _) {})),
      );
    }
  }

  Future<void> prefetchPlaybackAround(
    HgVideoDetail detail,
    int currentEpisode,
  ) async {
    // 播放地址是短时票据，提前获取并缓存反而会让邻近集拿到过期地址。
    // 真正的邻近集预初始化由播放器的 PageView.prepare 完成。
    await prefetchVideoDetails([detail.id], limit: 1);
  }

  Future<void> prefetchDrama(int videoId, {int episode = 1}) async {
    try {
      final detail = await video(videoId);
      await prefetchPlaybackAround(detail, episode);
    } catch (_) {
      // 预加载失败不阻塞主流程。
    }
  }

  Future<void> likeComment(int videoId, int commentId, bool on) async {
    await _request(
      on ? 'POST' : 'DELETE',
      '/api/videos/$videoId/comments/$commentId/like',
    );
    _invalidateDataPrefix('comments:$videoId:');
  }

  Future<HgCommentPage> commentReplies(
    int videoId,
    int commentId, {
    int page = 1,
    int size = 20,
  }) async {
    final data = await _request(
      'GET',
      '/api/videos/$videoId/comments/$commentId/replies?page=$page&size=$size',
    );
    return HgCommentPage.fromJson(asMap(data));
  }

  Future<void> sendComment(
    int videoId,
    int episode,
    String text, {
    int? replyId,
  }) async {
    final path = replyId == null || replyId <= 0
        ? '/api/videos/$videoId/comments?ep=$episode'
        : '/api/videos/$videoId/comments';
    await _request(
      'POST',
      path,
      body: {
        'text': text,
        if (replyId != null && replyId > 0) 'reply_id': replyId,
      },
    );
    _invalidateDataPrefix('comments:$videoId:$episode:');
  }

  Future<void> like(int videoId, int episode, bool on) async {
    await _request(
      on ? 'POST' : 'DELETE',
      '/api/videos/$videoId/like?ep=$episode',
    );
  }

  Future<void> collect(int videoId, bool on) async {
    await _request(on ? 'POST' : 'DELETE', '/api/videos/$videoId/collect');
  }

  Future<void> follow(int userId, bool on) async {
    await _request(on ? 'POST' : 'DELETE', '/api/users/$userId/follow');
  }

  Future<HgUser> user(int userId) async {
    return HgUser.fromJson(asMap(await _request('GET', '/api/users/$userId')));
  }

  Future<HgPage<HgVideoCard>> videosByUser(
    int userId, {
    int page = 1,
    int size = 20,
  }) async {
    final data = await _request(
      'GET',
      '/api/videos/user/$userId?page=$page&size=$size',
    );
    return HgPage.fromJson(asMap(data), HgVideoCard.fromJson);
  }

  Future<HgUserStats> userStats(int userId) async {
    return HgUserStats.fromJson(
      asMap(await _request('GET', '/api/users/$userId/stats')),
    );
  }

  Future<HgPage<HgAuthor>> myFollows({int page = 1, int size = 30}) async {
    final data = await _request(
      'GET',
      '/api/users/me/follows?page=$page&size=$size',
    );
    return HgPage.fromJson(asMap(data), HgAuthor.fromJson);
  }

  Future<HgPage<HgAuthor>> myFollowers({int page = 1, int size = 30}) async {
    final paths = [
      '/api/users/me/followers?page=$page&size=$size',
      '/api/users/me/follows?type=followers&page=$page&size=$size',
      '/api/users/me/follows?relation=followers&page=$page&size=$size',
    ];
    Object? lastError;
    for (final path in paths) {
      try {
        final data = await _request('GET', path);
        final pageData = asMap(data);
        if (pageData['items'] is List) {
          return HgPage.fromJson(pageData, HgAuthor.fromJson);
        }
        lastError = const HgApiException('粉丝列表接口格式不兼容');
      } on HgLoginRequiredException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? const HgApiException('粉丝列表暂不可用');
  }

  Future<HgPage<HgUserMessage>> myMessages({
    int page = 1,
    int size = 30,
  }) async {
    final data = await _request(
      'GET',
      '/api/users/me/messages?page=$page&size=$size',
    );
    return HgPage.fromJson(asMap(data), HgUserMessage.fromJson);
  }

  Future<int> unreadMessageCount() async {
    final data = await _request('GET', '/api/users/me/messages/unread-count');
    if (data is num) return data.round();
    if (data is String) return int.tryParse(data) ?? 0;
    final map = asMap(data);
    return asInt(
      map['count'] ?? map['unread'] ?? map['unread_count'] ?? map['total'],
    );
  }

  Future<void> markMessageRead(int messageId) async {
    await _request('POST', '/api/users/me/messages/$messageId/read');
  }

  Future<void> markAllMessagesRead() async {
    await _request('POST', '/api/users/me/messages/read-all');
  }

  Future<void> deleteMessage(int messageId) async {
    await _request('DELETE', '/api/users/me/messages/$messageId');
  }

  Future<HgPage<HgPlaylistItem>> myCollects({
    int page = 1,
    int size = 20,
  }) async {
    final data = await _request(
      'GET',
      '/api/users/me/collects?page=$page&size=$size',
    );
    return HgPage.fromJson(asMap(data), HgPlaylistItem.fromJson);
  }

  Future<HgPage<HgPlaylistItem>> myLikes({int page = 1, int size = 20}) async {
    final data = await _request(
      'GET',
      '/api/users/me/likes?page=$page&size=$size',
    );
    return HgPage.fromJson(asMap(data), HgPlaylistItem.fromJson);
  }

  Future<HgPage<HgPlaylistItem>> myHistory({
    int page = 1,
    int size = 20,
  }) async {
    final data = await _request(
      'GET',
      '/api/users/me/history?page=$page&size=$size',
    );
    return HgPage.fromJson(asMap(data), HgPlaylistItem.fromJson);
  }

  static const _sourceResolvers = [
    'https://huangguoai.com',
    'https://huangguoai.ai',
    'https://hgai16.com',
    'https://huangguoai.pages.dev',
    'https://huang-guo.pages.dev',
  ];

  static const _githubSourceManifestUrl = String.fromEnvironment(
    'HG_GITHUB_SOURCE_MANIFEST_URL',
    defaultValue:
        'https://api.github.com/repos/DearLicy/guomu/contents/assets/data/source_manifest.json',
  );

  static const _githubSourceManifestMirrors = [
    'https://cdn.jsdelivr.net/gh/DearLicy/guomu@main/assets/source_manifest.json',
    'https://raw.githubusercontent.com/DearLicy/guomu/main/assets/source_manifest.json',
  ];

  static Future<List<String>> discoverSources({
    Iterable<String> seeds = const [],
  }) async {
    final found = <String>{...seeds};
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 4),
        headers: {'Accept': '*/*', ...hgMediaHeaders()},
      ),
    );

    Future<void> addPayload(String base, String path) async {
      try {
        final response = await dio.get<String>(
          '$base$path',
          options: Options(responseType: ResponseType.plain),
        );
        final body = response.data ?? '';
        if (body.isEmpty) return;
        if (path.endsWith('publish.js')) {
          _collectSourceText(body, found);
          return;
        }
        dynamic decoded;
        try {
          decoded = jsonDecode(body);
        } catch (_) {
          // 发布页可能是 HTML，继续从文本中提取地址。
        }
        _collectSourceJson(decoded, found);
        _collectSourceText(body, found);
      } catch (_) {
        // 单个发布页不可用不影响其他线路。
      }
    }

    Future<void> probeResolver(String resolver) async {
      await Future.wait([
        addPayload(resolver, '/api/site/entries'),
        addPayload(resolver, '/api/site/go-home'),
        addPayload(resolver, '/publish.js'),
      ]);
    }

    await Future.wait(_sourceResolvers.map(probeResolver));
    for (final manifestUrl in <String>{
      _githubSourceManifestUrl,
      ..._githubSourceManifestMirrors,
    }) {
      try {
        final response = await dio.get<String>(
          manifestUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'Accept': manifestUrl.contains('api.github.com')
                  ? 'application/vnd.github.raw+json'
                  : '*/*',
            },
          ),
        );
        final body = response.data ?? '';
        if (body.isNotEmpty) {
          _collectSourceText(body, found);
          break;
        }
      } catch (_) {
        // GitHub Raw 不可达时继续尝试 jsDelivr；两者都失败仍保留官方发布页与内置源。
      }
    }
    final result = <String>[];
    for (final value in found) {
      final normalized = _normalizeDiscoveredSource(value);
      if (normalized != null && !result.contains(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  static Future<bool> probeSource(String value) async {
    final base = normalizeHgBaseUrl(value);
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 3),
        headers: {'Accept': 'application/json', ...hgMediaHeadersFor(base)},
      ),
    );
    try {
      final response = await dio.get<String>(
        '$base/api/site/entries',
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data ?? '';
      return body.contains('"entries"') || body.contains('"data"');
    } catch (_) {
      return false;
    }
  }

  static void _collectSourceJson(dynamic value, Set<String> found) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key == 'url' || key == 'domain' || key == 'home') {
          final candidate = entry.value?.toString() ?? '';
          if (candidate.isNotEmpty) found.add(candidate);
        }
        _collectSourceJson(entry.value, found);
      }
    } else if (value is List) {
      for (final item in value) {
        _collectSourceJson(item, found);
      }
    }
  }

  static void _collectSourceText(String text, Set<String> found) {
    final urlPattern = RegExp(r'https?://[a-zA-Z0-9.-]+(?::\d+)?');
    for (final match in urlPattern.allMatches(text)) {
      found.add(match.group(0)!);
    }
    final quotedDomainPattern = RegExp(
      r"'([a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+)(?:/[^']*)?'",
    );
    for (final match in quotedDomainPattern.allMatches(text)) {
      found.add(match.group(1)!);
    }
  }

  static String? _normalizeDiscoveredSource(String value) {
    var candidate = value.trim();
    if (candidate.isEmpty) return null;
    if (candidate.contains('{') || candidate.contains('}')) return null;
    if (!candidate.contains('://')) candidate = 'https://$candidate';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    if (host == 'huangguoai.ai' ||
        host == 'hgai16.com' ||
        host.endsWith('.pages.dev')) {
      return null;
    }
    if (host == 'bmikbxhi.cc' ||
        host == 'ixgukkejj.cc' ||
        host == 'fvlelaqt.cc') {
      return null;
    }
    final isContentSource =
        host == 'huangguoai.com' ||
        host.endsWith('.huangguoai.com') ||
        host.contains('drleao.cn') ||
        host.contains('bmikbxhi.cc') ||
        host.contains('fvlelaqt.cc') ||
        host.contains('psmvjggyd.cc') ||
        host.contains('ixgukkejj.cc');
    if (!isContentSource) return null;
    try {
      return normalizeHgBaseUrl(candidate);
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    final encodedBody = body == null
        ? ''
        : base64Encode(utf8.encode(jsonEncode(body)));
    final envelope = <String, dynamic>{
      'method': method.toUpperCase(),
      'path': path,
      'body': encodedBody,
      'content_type': body == null ? '' : 'application/json',
    };

    final requestVariants = <String>[];
    if (kIsWeb) {
      final proxyBase = _configuredWebProxyUrl.trim().isEmpty
          ? Uri.base.origin
          : _configuredWebProxyUrl.trim().replaceFirst(RegExp(r'/+$'), '');
      requestVariants.add(
        '$proxyBase/api/edge/request?source=${Uri.encodeQueryComponent(baseUrl)}',
      );
    }
    requestVariants.add('/api/edge/request');
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      for (final requestUrl in requestVariants) {
        try {
          // 原生包和 Web 都优先直接请求用户当前选择的数据源；Web 跨域失败时才使用本地预览代理兜底。
          final response = await _dio.post<dynamic>(
            requestUrl,
            data: envelope,
            options: Options(
              validateStatus: (_) => true,
              headers: {
                if (token != null && token!.isNotEmpty)
                  'Authorization': 'Bearer $token',
              },
            ),
          );
          return _decodeResponse(response);
        } on DioException catch (error) {
          lastError = error;
          // 继续尝试下一个传输方式；Web 直连被 CORS 拦截时回退到当前预览代理。
        }
      }
      if (kIsWeb) {
        try {
          final proxyDio = Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );
          final proxyBase = _configuredWebProxyUrl.trim().isEmpty
              ? Uri.base.origin
              : _configuredWebProxyUrl.trim().replaceFirst(RegExp(r'/+$'), '');
          final proxyUrl =
              '$proxyBase/api/edge/request?source=${Uri.encodeQueryComponent(baseUrl)}';
          final response = await proxyDio.post<dynamic>(
            proxyUrl,
            data: envelope,
            options: Options(
              validateStatus: (_) => true,
              headers: {
                if (token != null && token!.isNotEmpty)
                  'Authorization': 'Bearer $token',
              },
            ),
          );
          return _decodeResponse(response);
        } on DioException catch (error) {
          lastError = error;
        }
      }
      if (attempt == 2 ||
          (lastError is DioException && !_isRetryable(lastError))) {
        break;
      }
      await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }
    if (lastError is DioException) {
      throw HgApiException(_networkMessage(lastError));
    }
    throw const HgApiException('请求失败，请检查网络');
  }

  dynamic _decodeResponse(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status == 401 || status == 403) {
      throw const HgLoginRequiredException('登录状态已失效，请重新登录');
    }
    if (status < 200 || status >= 300) {
      throw HgApiException('请求失败（HTTP $status）', statusCode: status);
    }

    dynamic jsonValue = response.data;
    if (jsonValue is String) {
      if (jsonValue.trim().isEmpty) return null;
      try {
        jsonValue = jsonDecode(jsonValue);
      } on FormatException {
        throw const HgApiException('接口返回格式异常');
      }
    }
    if (jsonValue is! Map) {
      throw const HgApiException('接口返回格式异常');
    }

    final envelope = Map<String, dynamic>.from(jsonValue);
    if (asInt(envelope['status']) == 1) {
      return envelope['data'];
    }
    final message = asText(envelope['msg'], fallback: '接口返回失败');
    throw HgApiException(message, statusCode: status);
  }

  ({String token, HgUser user}) _sessionFromData(Map<String, dynamic> data) {
    final token = asText(data['token']);
    if (token.isEmpty) {
      throw const HgApiException('登录返回缺少 token');
    }
    return (token: token, user: HgUser.fromJson(asMap(data['user'])));
  }

  bool _isRetryable(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => (error.response?.statusCode ?? 0) >= 500,
      _ => false,
    };
  }

  String _networkMessage(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '连接超时，请稍后重试',
      DioExceptionType.connectionError => '无法连接黄果短剧服务',
      DioExceptionType.badCertificate => '站点证书校验失败',
      _ => error.message ?? '网络请求失败',
    };
  }
}
