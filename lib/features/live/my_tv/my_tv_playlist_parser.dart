import 'dart:convert';

import 'package:dashboard/features/live/live_playlist_parser.dart';
import 'package:dashboard/features/live/my_tv/my_tv_channel.dart';
import 'package:dashboard/features/live/my_tv/my_tv_group.dart';

/// Extends the host [LivePlaylistParser] with the my_tv specifics:
///
/// * TVbox `#genre#` sections and full-width `，` separators (handled by the
///   host parser once commas are normalised),
/// * `tvg-name` capture for XMLTV matching,
/// * the CCTV / 卫视 simplification filter,
/// * sequential channel numbering over the surviving channels.
class MyTvPlaylistParser {
  const MyTvPlaylistParser();

  List<MyTvGroup> parse(String source, {bool simplify = false}) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) return const [];
    if (_looksLikeJson(normalized)) {
      return _parseJsonChannels(normalized, simplify: simplify);
    }

    final isM3u = normalized.contains('#EXTINF:');
    final prepared = isM3u ? normalized : normalized.replaceAll('，', ',');
    final parsed = const LivePlaylistParser().parse(prepared);
    final tvgNames = isM3u
        ? _collectTvgNames(prepared)
        : const <String, String>{};

    final channels = <MyTvChannel>[];
    for (final channel in parsed) {
      if (simplify && !_keepUnderSimplify(channel.name)) continue;
      channels.add(
        MyTvChannel(
          number: channels.length + 1,
          name: channel.name,
          group: channel.group,
          tvgName: tvgNames[channel.name] ?? channel.id ?? channel.name,
          urls: channel.urls,
          logo: channel.logo,
        ),
      );
    }
    return _groupChannels(channels);
  }

  /// Extracts external live playlist links from TVBox JSON documents.
  /// The repository fetches these links through the same bounded HTTP path as
  /// ordinary M3U/TXT sources, then feeds each response back into [parse].
  List<({String name, Uri url})> sourceLinks(String source) {
    if (!_looksLikeJson(source)) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return const [];
    }
    final root = switch (decoded) {
      Map value => value,
      List value => {'lives': value},
      _ => null,
    };
    if (root == null) return const [];
    final candidates = <Object?>[];
    for (final key in ['lives', 'liveSources']) {
      final rows = root[key];
      if (rows is List) candidates.addAll(rows);
    }
    final output = <({String name, Uri url})>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final rawUrl = '${candidate['url'] ?? ''}'.trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          !<String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
          uri.host.isEmpty) {
        continue;
      }
      final name = '${candidate['name'] ?? candidate['title'] ?? '直播源'}'.trim();
      if (name.isNotEmpty && seen.add(uri.toString())) {
        output.add((name: name, url: uri));
      }
    }
    return output;
  }

  List<MyTvGroup> _parseJsonChannels(String source, {required bool simplify}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return const [];
    }
    final root = switch (decoded) {
      Map value => value,
      List value => {'channels': value},
      _ => null,
    };
    final rows = root?['channels'];
    if (rows is! List) return const [];
    final channels = <MyTvChannel>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final name = '${row['name'] ?? row['title'] ?? ''}'.trim();
      final group =
          '${row['group'] ?? row['groupName'] ?? row['group-title'] ?? '未分组'}'
              .trim();
      if (name.isEmpty || (simplify && !_keepUnderSimplify(name))) continue;
      final rawUrls = row['urls'] is List
          ? (row['urls'] as List)
          : [row['url']];
      final urls = rawUrls
          .map((value) => Uri.tryParse('${value ?? ''}'.trim()))
          .whereType<Uri>()
          .where(
            (uri) =>
                uri.hasScheme &&
                <String>{
                  'http',
                  'https',
                  'rtmp',
                  'rtsp',
                  'p2p',
                  'srt',
                  'udp',
                }.contains(uri.scheme.toLowerCase()),
          )
          .toList(growable: false);
      if (urls.isEmpty) continue;
      final rawLogo = Uri.tryParse(
        '${row['logo'] ?? row['tvg-logo'] ?? ''}'.trim(),
      );
      channels.add(
        MyTvChannel(
          number: channels.length + 1,
          name: name,
          group: group.isEmpty ? '未分组' : group,
          tvgName: '${row['tvgName'] ?? row['tvg-name'] ?? name}'.trim(),
          urls: urls,
          logo:
              rawLogo != null &&
                  <String>{
                    'http',
                    'https',
                  }.contains(rawLogo.scheme.toLowerCase())
              ? rawLogo
              : null,
        ),
      );
    }
    return _groupChannels(channels);
  }

  bool _looksLikeJson(String source) {
    final trimmed = source.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  /// Maps channel display name to its `tvg-name` attribute, if present.
  Map<String, String> _collectTvgNames(String source) {
    final names = <String, String>{};
    for (final line in source.split('\n')) {
      if (!line.startsWith('#EXTINF:')) continue;
      final comma = line.indexOf(',');
      if (comma < 0) continue;
      final name = line.substring(comma + 1).trim();
      final tvgName = _attribute(line, 'tvg-name');
      if (name.isNotEmpty && tvgName != null && tvgName.isNotEmpty) {
        names[name] = tvgName;
      }
    }
    return names;
  }

  String? _attribute(String line, String name) {
    final quoted = RegExp(
      '${RegExp.escape(name)}="([^"]*)"',
    ).firstMatch(line)?.group(1);
    if (quoted != null) return quoted;
    return RegExp(
      '${RegExp.escape(name)}=([^\\s,]+)',
    ).firstMatch(line)?.group(1);
  }

  bool _keepUnderSimplify(String name) {
    if (name.toLowerCase().startsWith('cctv')) return true;
    return name.endsWith('卫视');
  }

  List<MyTvGroup> _groupChannels(List<MyTvChannel> channels) {
    final grouped = <String, List<MyTvChannel>>{};
    for (final channel in channels) {
      grouped.putIfAbsent(channel.group, () => <MyTvChannel>[]).add(channel);
    }
    final groups = <MyTvGroup>[];
    for (final entry in grouped.entries) {
      groups.add(
        MyTvGroup(index: groups.length, name: entry.key, channels: entry.value),
      );
    }
    return groups;
  }
}
