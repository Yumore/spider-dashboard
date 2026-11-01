import 'package:dashboard/features/reading/book/importer/source_importer.dart';
import 'package:dashboard/features/reading/book/model/book_source.dart';
import 'package:dashboard/features/reading/book/repo/yckceo_repo.dart';
import 'package:dashboard/features/reading/book/repository/source_repository.dart';
import 'package:dashboard/features/reading/book/util/book_log.dart';
import 'package:dashboard/features/reading/book/view/source_manage_page.dart';
import 'package:dashboard/features/shared/ui/content_spacing.dart';
import 'package:dashboard/features/shared/ui/content_status.dart';
import 'package:dashboard/features/shared/ui/module_page_scaffold.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class SourceManagePageState extends State<SourceManagePage> {
  final SourceRepository _sources = SourceRepository.instance;
  final YckceoRepo _repo = YckceoRepo();
  final Dio _jsonDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.plain,
    ),
  );

  List<BookSource> _items = const <BookSource>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _sources.getAll();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e, st) {
      BookLog.e('Source', 'load failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _toggle(BookSource source, bool enabled) async {
    await _sources.setEnabled(source.bookSourceUrl, enabled);
    source.enabled = enabled;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _delete(BookSource source) async {
    await _sources.delete(source.bookSourceUrl);
    await _load();
  }

  Future<void> _importText() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入书源'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: '粘贴 Legado 书源 JSON（对象 / 数组）',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      final result = SourceImporter.parseJson(text);
      if (result.sources.isEmpty) {
        _toast('未解析到任何书源');
        return;
      }
      final stats = await _sources.upsertAllWithStats(result.sources);
      _toast(
        '导入完成：新增 ${stats.inserted} 个，更新 ${stats.updated} 个'
        '${result.duplicatesInBatch > 0 ? "，去重 ${result.duplicatesInBatch} 个" : ""}',
      );
      await _load();
    } catch (e, st) {
      BookLog.e('Source', 'import failed', error: e, stackTrace: st);
      _toast('导入失败：$e');
    }
  }

  /// Import every source from a YCK/Yckceo repository listing.
  ///
  /// The repository server only honours one id per JSON path
  /// (`YckceoRepo.multiSourceJsonUrl`), so items are imported one by one.
  Future<void> _importFromUrl() async {
    setState(() => _loading = true);
    try {
      final listing = await _repo.fetchSources(page: 1);
      if (listing.items.isEmpty) {
        setState(() => _loading = false);
        _toast('未在该仓库找到书源');
        return;
      }
      final imported = <BookSource>[];
      for (final item in listing.items) {
        if (item.jsonUrl.isEmpty) continue;
        try {
          final response = await _jsonDio.get<String>(item.jsonUrl);
          final json = response.data;
          if (json == null || json.isEmpty) continue;
          imported.addAll(SourceImporter.parseJson(json).sources);
        } catch (e) {
          BookLog.w('Source', 'repo item ${item.id} failed', error: e);
        }
      }
      if (imported.isEmpty) {
        setState(() => _loading = false);
        _toast('仓库中的书源下载失败');
        return;
      }
      final stats = await _sources.upsertAllWithStats(imported);
      await _load();
      _toast('导入完成：新增 ${stats.inserted} 个，更新 ${stats.updated} 个');
    } catch (e, st) {
      BookLog.e('Source', 'repo import failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('仓库导入失败：$e');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ModulePageScaffold(
      title: '书源管理',
      actions: [
        IconButton(
          tooltip: '从仓库导入',
          icon: const Icon(Icons.cloud_download_outlined),
          onPressed: _loading ? null : _importFromUrl,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importText,
        icon: const Icon(Icons.add),
        label: const Text('导入 JSON'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ContentStatusView(
        title: '书源加载失败',
        message: _error!,
        icon: Icons.error_outline,
        actionLabel: '重试',
        onAction: () => _load(),
      );
    }
    if (_items.isEmpty) {
      return ContentStatusView(
        title: '还没有书源',
        message: '导入 Legado JSON，或从公开书源仓库添加来源。',
        icon: Icons.source_outlined,
        actionLabel: '导入 JSON',
        onAction: () => _importText(),
      );
    }
    return ListView.separated(
      padding: ModulePageScaffold.pagePadding,
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: ContentSpacing.sm),
      itemBuilder: (context, index) {
        final source = _items[index];
        final enabled = source.enabled;
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            title: Text(
              source.bookSourceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${source.bookSourceGroup.isEmpty ? "未分组" : source.bookSourceGroup}\n'
              '${source.bookSourceUrl}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            leading: Switch(
              value: enabled,
              onChanged: (value) => _toggle(source, value),
            ),
            trailing: IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(source),
            ),
          ),
        );
      },
    );
  }
}
