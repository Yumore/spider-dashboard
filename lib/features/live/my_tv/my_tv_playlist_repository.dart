import 'package:dashboard/features/live/my_tv/my_tv_channel.dart';
import 'package:dashboard/features/live/my_tv/my_tv_group.dart';
import 'package:dashboard/features/live/my_tv/my_tv_playlist_parser.dart';
import 'package:dashboard/features/live/my_tv/my_tv_ttl_cache.dart';
import 'package:http/http.dart' as http;

/// Loads a playlist, using a 24h cache for the default public source.
class MyTvPlaylistRepository {
  MyTvPlaylistRepository({
    required Future<String> Function(Uri source) fetch,
    MyTvTtlCache? cache,
    MyTvPlaylistParser parser = const MyTvPlaylistParser(),
  }) : _fetch = fetch,
       _cache = cache,
       _parser = parser;

  /// Production repository backed by HTTP and [SharedPreferences].
  factory MyTvPlaylistRepository.production({
    http.Client? client,
    MyTvTtlCache? cache,
  }) {
    final httpClient = client ?? http.Client();
    return MyTvPlaylistRepository(
      cache: cache ?? MyTvTtlCache.preferences(key: 'my_tv_playlist'),
      fetch: (source) async {
        final response = await httpClient
            .get(source)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw Exception('直播源请求失败：HTTP ${response.statusCode}');
        }
        return response.body;
      },
    );
  }

  /// Public IPTV playlist used by the source app (ghproxy mirror).
  static const defaultSource =
      'https://mirror.ghproxy.com/https://raw.githubusercontent.com/zhumeng11/IPTV/main/IPTV.m3u';

  final Future<String> Function(Uri source) _fetch;
  final MyTvTtlCache? _cache;
  final MyTvPlaylistParser _parser;

  /// Fetches and parses [source], defaulting to [defaultSource].
  ///
  /// Only the default source is cached: a one-off custom URL must not
  /// overwrite (or be served from) the shared 24h cache slot.
  Future<List<MyTvGroup>> load({Uri? source, bool simplify = false}) async {
    final uri = source ?? Uri.parse(defaultSource);
    final useCache = source == null;
    if (useCache) {
      final cached = await _cache?.get();
      if (cached != null) return _parser.parse(cached, simplify: simplify);
    }
    final body = await _fetch(uri);
    if (useCache) await _cache?.put(body);
    final parsed = _parser.parse(body, simplify: simplify);
    if (parsed.isNotEmpty) return parsed;
    final links = _parser.sourceLinks(body);
    if (links.isEmpty) return const [];
    final groups = <MyTvGroup>[];
    for (final link in links.take(20)) {
      final childBody = await _fetch(link.url);
      final childGroups = _parser.parse(childBody, simplify: simplify);
      if (childGroups.isEmpty) {
        if (!_isHlsManifest(childBody)) continue;
        final channel = MyTvChannel(
          number: 1,
          name: link.name,
          group: link.name,
          tvgName: link.name,
          urls: [link.url],
        );
        groups.add(
          MyTvGroup(index: groups.length, name: link.name, channels: [channel]),
        );
        continue;
      }
      for (final group in childGroups) {
        groups.add(
          MyTvGroup(
            index: groups.length,
            name: link.name == '直播源'
                ? group.name
                : '${link.name} · ${group.name}',
            channels: group.channels,
          ),
        );
      }
    }
    return groups;
  }

  bool _isHlsManifest(String source) =>
      source.contains('#EXTM3U') &&
      (source.contains('#EXT-X-STREAM-INF') ||
          source.contains('#EXT-X-TARGETDURATION'));

  /// Re-parses already-fetched [source] (e.g. after toggling simplification).
  List<MyTvGroup> parse(String source, {bool simplify = false}) =>
      _parser.parse(source, simplify: simplify);
}
