import 'dart:convert';

import 'package:dashboard/features/short_drama/creator/ai_creator_client.dart';
import 'package:dashboard/features/short_drama/creator/creator_project.dart';

class CreatorAgentWorkflow {
  const CreatorAgentWorkflow(this._client);

  static const int _maxTurns = 5;
  static const int _maxDraftCharacters = 50000;
  static const int _maxContextCharacters = 80000;

  final AiCreatorClient _client;

  Future<String> createDraft({
    required CreatorProject project,
    required String targetSection,
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    final messages = <Map<String, dynamic>>[
      <String, dynamic>{
        'role': 'system',
        'content':
            '你是中文小说、短剧和 AI 漫剧创作 Agent。先调用 read_project_context '
            '读取项目现有设定，再创作“$targetSection”的原创草稿，最后调用 submit_draft 提交完整正文。'
            '不得调用其他工具、虚构项目上下文、仿写受版权保护的具体作品。',
      },
      <String, dynamic>{
        'role': 'user',
        'content':
            '项目：${project.title}\n类型：${project.kind}\n目标区块：$targetSection\n'
            '请读取现有上下文后生成可直接编辑的完整草稿，并通过 submit_draft 提交。',
      },
    ];
    final tools = <Map<String, Object>>[
      <String, Object>{
        'type': 'function',
        'function': <String, Object>{
          'name': 'read_project_context',
          'description': '读取当前项目已填写的创作区块，以保持设定一致。',
          'parameters': <String, Object>{
            'type': 'object',
            'properties': <String, Object>{},
            'required': <String>[],
          },
        },
      },
      <String, Object>{
        'type': 'function',
        'function': <String, Object>{
          'name': 'submit_draft',
          'description': '将生成的完整正文作为草稿返回给创作页。',
          'parameters': <String, Object>{
            'type': 'object',
            'properties': <String, Object>{
              'content': <String, Object>{
                'type': 'string',
                'description': '目标创作区块的完整草稿正文',
              },
            },
            'required': <String>['content'],
          },
        },
      },
    ];

    var contextRead = false;
    for (var turn = 0; turn < _maxTurns; turn++) {
      final response = await _client.complete(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
        messages: messages,
        tools: tools,
      );
      final choices = response['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw const FormatException('Agent 服务没有返回有效的工具调用');
      }
      final message = (choices.first as Map)['message'];
      if (message is! Map) {
        throw const FormatException('Agent 服务响应缺少 message');
      }
      messages.add(Map<String, dynamic>.from(message));
      final calls = message['tool_calls'];
      if (calls is! List || calls.isEmpty) {
        throw const FormatException('模型未调用工作流工具提交草稿');
      }

      for (final rawCall in calls) {
        if (rawCall is! Map) {
          throw const FormatException('Agent 工具调用格式无效');
        }
        final callId = rawCall['id'];
        final function = rawCall['function'];
        if (callId is! String || function is! Map) {
          throw const FormatException('Agent 工具调用缺少标识或函数');
        }
        final name = function['name'];
        final arguments = _decodeArguments(function['arguments']);
        if (name == 'read_project_context') {
          contextRead = true;
          messages.add(<String, dynamic>{
            'role': 'tool',
            'tool_call_id': callId,
            'content': _projectContext(project),
          });
          continue;
        }
        if (name == 'submit_draft') {
          if (!contextRead) {
            throw const FormatException('Agent 必须先读取项目上下文再提交草稿');
          }
          final content = arguments['content'];
          if (content is! String || content.trim().isEmpty) {
            throw const FormatException('Agent 提交的草稿为空');
          }
          if (content.length > _maxDraftCharacters) {
            throw const FormatException('Agent 草稿超过 50,000 个字符');
          }
          return content.trim();
        }
        throw const FormatException('Agent 请求了未开放的工具');
      }
    }
    throw const FormatException('Agent 未在规定轮数内提交草稿');
  }

  Map<String, dynamic> _decodeArguments(Object? rawArguments) {
    if (rawArguments is! String) {
      throw const FormatException('Agent 工具参数格式无效');
    }
    final decoded = jsonDecode(rawArguments);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Agent 工具参数必须是 JSON 对象');
    }
    return decoded;
  }

  String _projectContext(CreatorProject project) {
    var remainingCharacters = _maxContextCharacters;
    final sections = <String, String>{};
    for (final entry in project.sections.entries) {
      if (entry.value.trim().isEmpty || remainingCharacters <= 0) continue;
      final limit = remainingCharacters < 12000 ? remainingCharacters : 12000;
      final value = entry.value.length <= limit
          ? entry.value
          : '${entry.value.substring(0, limit)}…（内容已截断）';
      sections[entry.key] = value;
      remainingCharacters -= value.length + entry.key.length + 16;
    }
    final context = <String, Object>{
      'title': project.title,
      'kind': project.kind,
      'sections': sections,
    };
    return jsonEncode(context);
  }
}
