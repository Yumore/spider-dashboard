import 'dart:async';
import 'dart:math';

import 'package:dashboard/features/shared/ui/content_status.dart';
import 'package:dashboard/features/shared/ui/module_page_scaffold.dart';
import 'package:dashboard/features/short_drama/creator/ai_creator_client.dart';
import 'package:dashboard/features/short_drama/creator/creator_page.dart';
import 'package:dashboard/features/short_drama/creator/creator_project.dart';
import 'package:dashboard/features/short_drama/creator/creator_repository.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CreatorPageState extends State<CreatorPage> {
  final CreatorRepository _repository = CreatorRepository();
  final AiCreatorClient _aiClient = AiCreatorClient();
  final Map<String, TextEditingController> _sectionControllers =
      <String, TextEditingController>{};
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _projectTitleController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'https://api.openai.com/v1',
  );
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  List<CreatorProject> _projects = const <CreatorProject>[];
  CreatorProject? _selected;
  Timer? _saveTimer;
  bool _loading = true;
  bool _dirty = false;
  bool _generating = false;
  String? _error;
  String? _configuredApiKey;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final controller in _sectionControllers.values) {
      controller.dispose();
    }
    _titleController.dispose();
    _projectTitleController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _aiClient.close();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final projects = await _repository.loadProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _createProject() async {
    _titleController.clear();
    var kind = 'AI漫剧';
    final result = await showDialog<({String title, String kind})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('新建创作项目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '项目名称'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // Keep compatible with the project's Flutter 3.32 floor.
                // ignore: deprecated_member_use
                value: kind,
                decoration: const InputDecoration(labelText: '创作类型'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'AI漫剧', child: Text('AI 漫剧')),
                  DropdownMenuItem(value: '短剧', child: Text('短剧')),
                  DropdownMenuItem(value: '小说', child: Text('小说')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => kind = value);
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final title = _titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(dialogContext, (title: title, kind: kind));
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final now = DateTime.now();
    final sections = <String, String>{
      for (final section in creatorSectionsFor(result.kind)) section: '',
    };
    final project = CreatorProject(
      id: '${now.microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}',
      title: result.title,
      kind: result.kind,
      sections: sections,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.saveProject(project);
    if (!mounted) return;
    await _reload();
    if (!mounted) return;
    _openProject(project);
  }

  void _openProject(CreatorProject project) {
    _saveTimer?.cancel();
    _disposeSectionControllers();
    _selected = project;
    _projectTitleController.text = project.title;
    for (final entry in project.sections.entries) {
      _sectionControllers[entry.key] = TextEditingController(text: entry.value)
        ..addListener(_onSectionChanged);
    }
    _dirty = false;
    setState(() {});
  }

  void _disposeSectionControllers() {
    for (final controller in _sectionControllers.values) {
      controller
        ..removeListener(_onSectionChanged)
        ..dispose();
    }
    _sectionControllers.clear();
  }

  void _onSectionChanged() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_saveProject(showMessage: false));
    });
    if (mounted) setState(() {});
  }

  Future<bool> _saveProject({bool showMessage = true}) async {
    final project = _selected;
    if (project == null) return true;
    _saveTimer?.cancel();
    final updated = project.copyWith(
      sections: <String, String>{
        for (final entry in _sectionControllers.entries)
          entry.key: entry.value.text,
      },
      updatedAt: DateTime.now(),
    );
    try {
      await _repository.saveProject(updated);
      if (!mounted) return false;
      setState(() {
        _selected = updated;
        _dirty = false;
      });
      await _reload();
      if (showMessage && mounted) {
        _message('已保存到本机');
      }
      return true;
    } catch (error) {
      if (mounted) _message('保存失败：$error');
      return false;
    }
  }

  Future<void> _closeEditor() async {
    final saved = await _saveProject(showMessage: false);
    if (!saved || !mounted) return;
    _disposeSectionControllers();
    setState(() {
      _selected = null;
      _dirty = false;
    });
  }

  Future<void> _deleteProject(CreatorProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除项目？'),
        content: Text('“${project.title}”及其本机草稿将被删除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteProject(project.id);
    if (_selected?.id == project.id) {
      _disposeSectionControllers();
      _selected = null;
      _dirty = false;
    }
    await _reload();
  }

  Future<void> _configureAi() async {
    _apiKeyController.clear();
    final config =
        await showDialog<({String baseUrl, String model, String apiKey})>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('连接 AI 模型'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: _baseUrlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: '兼容 OpenAI 的 API 地址',
                      hintText: 'https://api.example.com/v1',
                      helperText: 'HTTP 地址会明文传输密钥，仅用于可信的本地网络服务。',
                    ),
                  ),
                  TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(labelText: '模型名称'),
                  ),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      helperText: '只保存在本次运行的内存中，不写入项目或设置。',
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final baseUrl = _baseUrlController.text.trim();
                  final model = _modelController.text.trim();
                  final apiKey = _apiKeyController.text.trim();
                  if (baseUrl.isEmpty || model.isEmpty || apiKey.isEmpty) {
                    _message('请填写 API 地址、模型名称和 API Key');
                    return;
                  }
                  Navigator.pop(dialogContext, (
                    baseUrl: baseUrl,
                    model: model,
                    apiKey: apiKey,
                  ));
                },
                child: const Text('连接'),
              ),
            ],
          ),
        );
    _apiKeyController.clear();
    if (config == null) return;
    _baseUrlController.text = config.baseUrl;
    _modelController.text = config.model;
    _configuredApiKey = config.apiKey;
    _message('模型配置仅在本次运行中有效');
  }

  Future<void> _generate(String section) async {
    final project = _selected;
    if (project == null || _generating) return;
    final target = _sectionControllers[section];
    if (target == null) return;
    if (target.text.trim().isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('替换当前草稿？'),
          content: Text('AI 生成的内容会替换“$section”当前文本。请先确认已保存重要内容。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('保留当前内容'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('继续生成'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    if (_configuredApiKey == null || _configuredApiKey!.isEmpty) {
      await _configureAi();
    }
    if (!mounted) return;
    final apiKey = _configuredApiKey;
    if (apiKey == null || apiKey.isEmpty) return;
    final contextText = <String>[
      '作品名：${project.title}',
      '作品类型：${project.kind}',
      for (final entry in _sectionControllers.entries)
        if (entry.key != section && entry.value.text.trim().isNotEmpty)
          '${entry.key}：${entry.value.text.trim()}',
    ].join('\n');
    final prompt = _promptFor(section, project.kind);
    setState(() => _generating = true);
    try {
      final generated = await _aiClient.generate(
        baseUrl: _baseUrlController.text,
        model: _modelController.text,
        apiKey: apiKey,
        systemPrompt:
            '你是专业的中文小说与短剧编剧。只返回适合写入“$section”的正文，不要解释过程。'
            '创作需原创，不复述或仿写受版权保护的具体作品。',
        userPrompt: '$contextText\n\n请为“$section”$prompt。',
      );
      final controller = _sectionControllers[section];
      if (controller == null || !mounted) return;
      controller.text = generated;
      _onSectionChanged();
      final saved = await _saveProject(showMessage: false);
      if (mounted) {
        _message(saved ? 'AI 草稿已生成并保存' : 'AI 草稿已生成，但本机保存失败');
      }
    } catch (error) {
      if (mounted) _message('生成失败：$error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _promptFor(String section, String kind) {
    if (section.contains('人物')) return '，包含目标、性格、外形和角色关系';
    if (section.contains('大纲')) return '，按可执行的章节/分集结构列出起承转合和结尾悬念';
    if (section.contains('剧本')) return '，按场次、动作、角色、对白的格式撰写';
    if (section.contains('分镜')) return '，逐镜给出景别、画面构图、动作、对白/音效及可用于 AI 生图的提示词';
    if (kind == '小说' && section.contains('正文')) return '，直接续写正文并保持已给出的设定一致';
    return '，提供原创、可继续扩写的设定和明确的戏剧冲突';
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), duration: const Duration(seconds: 3)),
    );
  }

  Widget _buildLibrary() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ContentStatusView(
        title: '创作项目加载失败',
        message: _error!,
        icon: Icons.error_outline,
        actionLabel: '重试',
        onAction: () => _reload(),
      );
    }
    return ListView(
      padding: ModulePageScaffold.pagePadding,
      children: <Widget>[
        if (_projects.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: ContentStatusView(
              title: '还没有创作项目',
              message: '新建小说、短剧或 AI 漫剧项目，草稿保存在本机。',
              icon: Icons.auto_awesome_outlined,
            ),
          ),
        for (final project in _projects)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_motion_outlined),
              title: Text(project.title),
              subtitle: Text(
                '${project.kind} · ${_projectProgress(project)} 个创作区块 · '
                '更新于 ${_formatDate(project.updatedAt)}',
              ),
              trailing: IconButton(
                tooltip: '删除项目',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteProject(project),
              ),
              onTap: () => _openProject(project),
            ),
          ),
        const SizedBox(height: 20),
        _buildAttribution(),
      ],
    );
  }

  int _projectProgress(CreatorProject project) =>
      project.sections.values.where((value) => value.trim().isNotEmpty).length;

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Widget _buildEditor(CreatorProject project) {
    return ListView(
      padding: ModulePageScaffold.pagePadding,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  project.kind,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                TextField(
                  controller: _projectTitleController,
                  readOnly: _generating,
                  decoration: const InputDecoration(labelText: '项目名称'),
                  onChanged: (value) {
                    final selected = _selected;
                    if (selected == null || value.trim().isEmpty) return;
                    _selected = selected.copyWith(title: value.trim());
                    _dirty = true;
                    _scheduleSave();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
        for (final entry in _sectionControllers.entries)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: '用 AI 生成草稿',
                        onPressed: _generating
                            ? null
                            : () => _generate(entry.key),
                        icon: _generating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                      ),
                    ],
                  ),
                  TextField(
                    controller: entry.value,
                    readOnly: _generating,
                    minLines: 5,
                    maxLines: 18,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: '记录${entry.key}，输入内容会自动保存到本机',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        _buildAttribution(),
      ],
    );
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_saveProject(showMessage: false));
    });
  }

  Widget _buildAttribution() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const Text('创作工作流参考 Reveric；Based on Reveric by looplj。'),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/looplj/reveric'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('项目主页'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return PopScope<void>(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selected != null && !_generating) {
          unawaited(_closeEditor());
        }
      },
      child: ModulePageScaffold(
        title: selected == null ? '小说与 AI 漫剧创作' : selected.title,
        actions: <Widget>[
          if (selected != null)
            IconButton(
              tooltip: _dirty ? '保存更改' : '已保存',
              onPressed: _dirty ? () => _saveProject() : null,
              icon: Icon(
                _dirty ? Icons.save_outlined : Icons.cloud_done_outlined,
              ),
            ),
          if (selected != null)
            IconButton(
              tooltip: '模型设置',
              onPressed: _generating ? null : _configureAi,
              icon: const Icon(Icons.tune_outlined),
            ),
          if (selected == null)
            IconButton(
              tooltip: '新建项目',
              onPressed: _createProject,
              icon: const Icon(Icons.add),
            )
          else
            IconButton(
              tooltip: '返回项目列表',
              onPressed: _generating ? null : _closeEditor,
              icon: const Icon(Icons.close),
            ),
        ],
        floatingActionButton: selected == null
            ? FloatingActionButton.extended(
                onPressed: _createProject,
                icon: const Icon(Icons.add),
                label: const Text('新建创作'),
              )
            : null,
        body: selected == null ? _buildLibrary() : _buildEditor(selected),
      ),
    );
  }
}
