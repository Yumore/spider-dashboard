import 'package:dashboard/features/reading/pdf_tools/pdf_document_inspection.dart';
import 'package:dashboard/features/reading/pdf_tools/pdf_document_tools.dart';
import 'package:dashboard/features/reading/pdf_tools/pdf_tools_page.dart';
import 'package:dashboard/features/shared/ui/module_page_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PdfToolsPageState extends State<PdfToolsPage> {
  final PdfDocumentTools _tools = PdfDocumentTools();

  PdfDocumentInspection? _inspection;
  String? _inspectionFileName;
  List<PlatformFile> _mergeFiles = const [];
  bool _parsing = false;
  bool _merging = false;

  Future<void> _inspectPdf() async {
    if (_parsing || _merging) return;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (file == null || !mounted) return;
      final size = await _fileSize(file);
      if (!mounted) return;
      if (size > _tools.maxSingleFileBytes) {
        _showMessage(
          '此平台单个 PDF 的处理上限为 ${_formatSize(_tools.maxSingleFileBytes)}',
        );
        return;
      }
      setState(() {
        _parsing = true;
        _inspection = null;
        _inspectionFileName = file.name;
      });
      final result = await _tools.inspect(await file.readAsBytes());
      if (mounted) setState(() => _inspection = result);
    } catch (error) {
      if (mounted) _showMessage('PDF 解析失败：${_friendlyError(error)}');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _chooseMergeFiles() async {
    if (_parsing || _merging) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (!mounted) return;
      if (result.isEmpty) return;
      if (result.length < 2) {
        _showMessage('至少选择两个 PDF 文件');
        return;
      }
      if (result.length > PdfDocumentTools.maxMergeFileCount) {
        _showMessage('最多可合并 ${PdfDocumentTools.maxMergeFileCount} 个 PDF');
        return;
      }
      final sizes = await Future.wait(result.map(_fileSize));
      if (!mounted) return;
      final totalSize = sizes.fold<int>(0, (total, size) => total + size);
      if (totalSize > _tools.maxMergeBytes) {
        _showMessage('合并文件总大小超过 ${_formatSize(_tools.maxMergeBytes)}');
        return;
      }
      setState(() => _mergeFiles = result);
    } catch (error) {
      if (mounted) _showMessage('选择文件失败：${_friendlyError(error)}');
    }
  }

  Future<void> _mergePdfs() async {
    if (_merging || _parsing || _mergeFiles.length < 2) return;
    setState(() => _merging = true);
    try {
      final inputs = <Uint8List>[];
      var totalBytes = 0;
      for (final file in _mergeFiles) {
        final expectedSize = await _fileSize(file);
        if (expectedSize > _tools.maxSingleFileBytes) {
          throw FormatException('${file.name} 超过单文件处理大小限制');
        }
        final bytes = await file.readAsBytes();
        if (bytes.length > _tools.maxSingleFileBytes) {
          throw FormatException('${file.name} 超过单文件处理大小限制');
        }
        totalBytes += bytes.length;
        if (totalBytes > _tools.maxMergeBytes) {
          throw FormatException('PDF 合并总大小超过当前平台的处理限制');
        }
        inputs.add(bytes);
      }
      final merged = await _tools.merge(inputs);
      final saved = await FilePicker.saveFile(
        fileName: 'merged-${DateTime.now().millisecondsSinceEpoch}.pdf',
        bytes: merged,
        mimeType: 'application/pdf',
      );
      if (saved != null && mounted) _showMessage('已保存合并后的 PDF');
    } catch (error) {
      if (mounted) _showMessage('PDF 合并失败：${_friendlyError(error)}');
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  void _reorderMergeFiles(int oldIndex, int newIndex) {
    final next = [..._mergeFiles];
    if (newIndex > oldIndex) newIndex--;
    final file = next.removeAt(oldIndex);
    next.insert(newIndex, file);
    setState(() => _mergeFiles = next);
  }

  Future<int> _fileSize(PlatformFile file) async {
    final size = await file.length() ?? file.lengthSync();
    if (size == null) {
      throw FormatException('无法读取 ${file.name} 的文件大小');
    }
    return size;
  }

  Future<void> _copyText() async {
    final text = _inspection?.textPreview;
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _showMessage('已复制解析出的文本');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    if (error is FormatException) return error.message;
    return '文件可能已损坏、受密码保护，或格式不受支持。';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return ModulePageScaffold(
      title: 'PDF 解析与合并',
      body: ListView(
        padding: ModulePageScaffold.pagePadding,
        children: [
          _buildParserCard(),
          const SizedBox(height: 16),
          _buildMergeCard(),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('文件在本机处理，不会上传。文字提取针对 PDF 内已有文本层；扫描件 OCR 暂未接入。'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParserCard() {
    final inspection = _inspection;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('解析 PDF', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('读取页数、文档标题、作者和文本层内容。'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _parsing || _merging ? null : _inspectPdf,
              icon: _parsing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.manage_search_outlined),
              label: Text(_parsing ? '正在解析…' : '选择 PDF 并解析'),
            ),
            if (inspection != null) ...[
              const Divider(height: 28),
              Text(
                _inspectionFileName ?? 'PDF 文档',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('页数：${inspection.pageCount}'),
              if (inspection.title.isNotEmpty) Text('标题：${inspection.title}'),
              if (inspection.author.isNotEmpty) Text('作者：${inspection.author}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inspection.textPreview.isEmpty
                          ? '没有提取到文本，文档可能是扫描图像。'
                          : '文本预览',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (inspection.textPreview.isNotEmpty)
                    IconButton(
                      tooltip: '复制文本',
                      onPressed: _copyText,
                      icon: const Icon(Icons.copy_outlined),
                    ),
                ],
              ),
              if (inspection.textPreview.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(inspection.textPreview),
                  ),
                ),
              if (inspection.truncated)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('文本预览已截断；完整解析上限为 300 页或 50,000 个字符。'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMergeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('合并 PDF', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('选择多个文件并拖动排序，合并结果会保存为新的 PDF。'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _parsing || _merging ? null : _chooseMergeFiles,
              icon: const Icon(Icons.library_add_outlined),
              label: const Text('选择多个 PDF'),
            ),
            if (_mergeFiles.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: (_mergeFiles.length * 64.0).clamp(64.0, 320.0),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: _mergeFiles.length,
                  // Keep compatible with the project's Flutter 3.32 floor.
                  // ignore: deprecated_member_use
                  onReorder: _reorderMergeFiles,
                  itemBuilder: (context, index) {
                    final file = _mergeFiles[index];
                    return ListTile(
                      key: ObjectKey(file),
                      leading: Text('${index + 1}'),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: const Text('PDF 文件'),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _parsing || _merging ? null : _mergePdfs,
                icon: _merging
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.merge_type_outlined),
                label: Text(_merging ? '正在合并…' : '合并并保存'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
