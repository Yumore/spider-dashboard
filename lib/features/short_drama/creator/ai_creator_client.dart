import 'dart:convert';

import 'package:http/http.dart' as http;

class AiCreatorClient {
  AiCreatorClient({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  Future<String> generate({
    required String baseUrl,
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final decoded = await complete(
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      messages: <Map<String, dynamic>>[
        <String, dynamic>{'role': 'system', 'content': systemPrompt},
        <String, dynamic>{'role': 'user', 'content': userPrompt},
      ],
    );
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const FormatException('模型服务没有返回创作内容');
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map) {
      throw const FormatException('模型服务响应缺少 message');
    }
    final content = _textFromContent(message['content']);
    if (content.trim().isEmpty) {
      throw const FormatException('模型服务返回了空内容');
    }
    return content.trim();
  }

  Future<Map<String, dynamic>> complete({
    required String baseUrl,
    required String model,
    required String apiKey,
    required List<Map<String, dynamic>> messages,
    List<Map<String, Object>>? tools,
  }) async {
    final uri = _completionUri(baseUrl);
    final payload = <String, Object>{
      'model': model,
      'temperature': 0.75,
      'messages': messages,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
    };
    final response = await _client
        .post(
          uri,
          headers: <String, String>{
            'authorization': 'Bearer $apiKey',
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.length > 500
          ? response.body.substring(0, 500)
          : response.body;
      throw Exception('模型服务返回 HTTP ${response.statusCode}: $detail');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('模型服务响应格式无效');
    }
    return decoded;
  }

  String _textFromContent(Object? content) {
    if (content is String) return content;
    if (content is! List) return '';
    return content
        .whereType<Map>()
        .map((part) => part['text']?.toString() ?? '')
        .where((part) => part.isNotEmpty)
        .join('\n');
  }

  Uri _completionUri(String baseUrl) {
    final uri = Uri.parse(baseUrl.trim());
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('请输入有效的 HTTP(S) 模型服务地址');
    }
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    final completionPath = path.endsWith('/chat/completions')
        ? path
        : '$path/chat/completions';
    return uri.replace(path: completionPath, query: null, fragment: null);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
