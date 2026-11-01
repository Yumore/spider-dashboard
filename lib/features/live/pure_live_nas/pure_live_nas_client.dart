import 'dart:convert';

import 'package:dashboard/features/live/pure_live_nas/pure_live_nas_endpoint_store.dart';
import 'package:http/http.dart' as http;

/// Checks the public health endpoint exposed by the migrated NAS server.
class PureLiveNasClient {
  const PureLiveNasClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<void> checkHealth(String endpoint) async {
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .get(Uri.parse('$endpoint/api/health'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw StateError('NAS 健康检查返回 HTTP ${response.statusCode}');
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['ok'] != true) {
        throw const FormatException('NAS 健康检查响应格式无效');
      }
    } finally {
      if (ownsClient) client.close();
    }
  }
}
