import 'dart:convert';

import 'package:dashboard/features/movie/tvbox/tvbox_source_site.dart';

/// Parses TVBox and LibreTV source-list documents into direct CMS endpoints.
class TvBoxSourceCatalogParser {
  List<TvBoxSourceSite> parse(String content, {Uri? baseUri}) {
    final Object? decoded = jsonDecode(content);
    final Map<String, Object?>? document = switch (decoded) {
      Map value => value.map((key, value) => MapEntry(key.toString(), value)),
      List value => {'sites': value},
      _ => null,
    };
    if (document == null) {
      throw const FormatException('源配置必须是 JSON 对象或数组');
    }

    final candidates = <({Object? raw, bool libre})>[];
    final sites = document['sites'];
    if (sites is List) {
      candidates.addAll(sites.map((raw) => (raw: raw, libre: false)));
    }
    final sources = document['sources'];
    if (sources is List) {
      candidates.addAll(sources.map((raw) => (raw: raw, libre: true)));
    }

    final result = <TvBoxSourceSite>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      final raw = candidate.raw;
      if (raw is! Map) continue;
      final row = raw.map((key, value) => MapEntry(key.toString(), value));
      final type = int.tryParse('${row['type'] ?? (candidate.libre ? 1 : 3)}');
      // TVBox type 1 is the common MacCMS JSON protocol. Spider JS, XML,
      // audio-only and executable extension formats need separate runtimes.
      if (type != 1) continue;
      if (row['searchable'] == false ||
          row['searchable'] == 0 ||
          row['searchable'] == '0') {
        continue;
      }
      final rawApi = '${row['api'] ?? row['url'] ?? ''}'.trim();
      final parsedApi = Uri.tryParse(rawApi);
      final api = parsedApi != null && !parsedApi.hasScheme && baseUri != null
          ? baseUri.resolveUri(parsedApi)
          : parsedApi;
      if (api == null ||
          !<String>{'http', 'https'}.contains(api.scheme.toLowerCase()) ||
          api.host.isEmpty) {
        continue;
      }
      final key = '${row['key'] ?? row['id'] ?? rawApi}'.trim();
      final name = '${row['name'] ?? row['title'] ?? key}'.trim();
      if (key.isEmpty ||
          name.isEmpty ||
          !seen.add('${key.toLowerCase()}\u0000$rawApi')) {
        continue;
      }
      result.add(TvBoxSourceSite(key: key, name: name, api: api));
    }
    if (result.isEmpty) {
      throw const FormatException('配置中没有可搜索的 HTTP(S) TVBox CMS JSON 源');
    }
    return result;
  }
}
