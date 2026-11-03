import 'package:dashboard/features/reading/local_library/local_reading_file_store.dart';
import 'package:dashboard/features/reading/local_library/local_reading_import_service.dart';
import 'package:dashboard/features/reading/local_library/local_reading_library_page.dart';
import 'package:dashboard/features/reading/local_library/local_reading_library_repository.dart';
import 'package:dashboard/features/reading/local_library/local_reading_record.dart';
import 'package:dashboard/features/reading/local_library/local_reading_reader_page.dart';
import 'package:dashboard/features/reading/local_library/reader_session_repository.dart';
import 'package:dashboard/features/shared/ui/module_page_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class LocalReadingLibraryPageState extends State<LocalReadingLibraryPage> {
  final LocalReadingLibraryRepository _repository =
      LocalReadingLibraryRepository();
  final LocalReadingFileStore _fileStore = LocalReadingFileStore();
  late final LocalReadingImportService _importService =
      LocalReadingImportService(repository: _repository, fileStore: _fileStore);

  List<LocalReadingRecord> _records = const [];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await _repository.loadAll();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _importDocument() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub', 'pdf'],
      );
      if (files.isEmpty || !mounted) return;
      await _importService.importFile(files.first);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已加入本地书库')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _open(LocalReadingRecord record) async {
    try {
      await Navigator.of(
        context,
      ).push<void>(LocalReadingReaderPage.route(record: record));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开文件：$error')));
      }
    }
  }

  Future<void> _delete(LocalReadingRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除这本书？'),
        content: Text('“${record.name}”及其应用内副本、阅读笔记会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _fileStore.deleteFile(record.path);
      await _repository.remove(record.id);
      await ReaderSessionRepository().clear(record.id);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('移除失败：$error')));
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return ModulePageScaffold(
      title: '电子书与教材',
      actions: [
        IconButton(
          tooltip: '导入 EPUB 或 PDF',
          onPressed: _importing ? null : _importDocument,
          icon: _importing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? _emptyState()
          : ListView.separated(
              padding: ModulePageScaffold.pagePadding,
              itemCount: _records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final record = _records[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(
                      record.format == 'pdf'
                          ? Icons.picture_as_pdf_outlined
                          : Icons.menu_book_outlined,
                    ),
                    title: Text(
                      record.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${record.format.toUpperCase()} · ${_formatSize(record.sizeBytes)}',
                    ),
                    onTap: () => _open(record),
                    trailing: IconButton(
                      tooltip: '移除',
                      onPressed: () => _delete(record),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('导入本地 EPUB 电子书或 PDF 教材，阅读位置和批注会保存在本机。'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _importDocument,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('选择文件'),
          ),
        ],
      ),
    ),
  );
}
