import 'dart:convert';

import 'package:dashboard/features/movie/tvbox/tvbox_source_catalog_parser.dart';
import 'package:dashboard/features/movie/tvbox/tvbox_source_site.dart';
import 'package:dashboard/features/movie/tvbox/tvbox_vod_item.dart';
import 'package:dio/dio.dart';

/// Network adapter for user-selected TVBox type-1 CMS JSON sources.
class TvBoxCmsClient {
  TvBoxCmsClient({Dio? dio, TvBoxSourceCatalogParser? parser})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {'Accept': 'application/json, text/plain, */*'},
            ),
          ),
      _parser = parser ?? TvBoxSourceCatalogParser();

  final Dio _dio;
  final TvBoxSourceCatalogParser _parser;

  Future<List<TvBoxSourceSite>> loadCatalog(Uri config) async {
    _requireHttp(config);
    final response = await _dio.get<String>(
      config.toString(),
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';
    if (body.isEmpty) throw const FormatException('源配置为空');
    return _parser.parse(body, baseUri: config);
  }

  Future<List<TvBoxVodItem>> search(
    TvBoxSourceSite site,
    String keyword, {
    int page = 1,
  }) async {
    final response = await _request(site.api, {
      'ac': 'list',
      'wd': keyword.trim(),
      'pg': page,
    });
    return _rows(response)
        .map((row) => TvBoxVodItem.fromJson(row, site.api))
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<TvBoxVodItem> detail(TvBoxSourceSite site, String id) async {
    final response = await _request(site.api, {'ac': 'detail', 'ids': id});
    final rows = _rows(response);
    if (rows.isEmpty) throw const FormatException('源没有返回影片详情');
    return TvBoxVodItem.fromJson(rows.first, site.api);
  }

  Future<Object?> _request(Uri endpoint, Map<String, Object> query) async {
    _requireHttp(endpoint);
    final uri = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        ...query.map((key, value) => MapEntry(key, '$value')),
      },
    );
    final response = await _dio.get<String>(
      uri.toString(),
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw FormatException('CMS 返回的不是 JSON：${error.message}');
    }
  }

  List<Map<String, Object?>> _rows(Object? response) {
    Object? rows = response;
    if (rows is Map) {
      rows =
          rows['list'] ?? (rows['data'] is Map ? rows['data']['list'] : null);
    }
    if (rows is! List) throw const FormatException('CMS 响应缺少 list 列表');
    return rows
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  void _requireHttp(Uri uri) {
    if (!<String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      throw const FormatException('源地址必须使用 HTTP/HTTPS');
    }
  }

  void dispose() => _dio.close();
}
