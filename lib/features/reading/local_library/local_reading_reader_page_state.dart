import 'dart:async';

import 'package:dashboard/features/reading/local_library/local_reading_file_store.dart';
import 'package:dashboard/features/reading/local_library/local_reading_reader_page.dart';
import 'package:dashboard/features/reading/local_library/reader_annotation.dart';
import 'package:dashboard/features/reading/local_library/reader_session_repository.dart';
import 'package:flutter/material.dart';
import 'package:papyrus_reader/papyrus_reader.dart';

class LocalReadingReaderPageState extends State<LocalReadingReaderPage> {
  final ReaderSessionRepository _sessions = ReaderSessionRepository();
  final LocalReadingFileStore _fileStore = LocalReadingFileStore();

  ReaderController? _controller;
  ReaderLocator? _initialLocator;
  List<ReaderAnnotation> _annotations = const [];

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final record = widget.record;
    final values = await Future.wait<Object?>([
      _sessions.loadLocator(record.id),
      _sessions.loadPreferences(record.id),
      _sessions.loadAnnotations(record.id),
    ]);
    if (!mounted) return;
    final annotations = values[2] as List<ReaderAnnotation>;
    final controller = ReaderController(
      registry: ReaderEngineRegistry.defaults(),
      initialPreferences:
          values[1] as ReaderPreferences? ?? const ReaderPreferences(),
      onLocatorChanged: (locator) {
        unawaited(_sessions.saveLocator(record.id, locator));
      },
      onPreferencesChanged: (preferences) {
        unawaited(_sessions.savePreferences(record.id, preferences));
      },
    );
    setState(() {
      _initialLocator = values[0] as ReaderLocator?;
      _annotations = annotations;
      _controller = controller;
    });
  }

  void _addAnnotation(ReaderSelection selection) {
    unawaited(_editAnnotation(selection: selection));
  }

  void _editHighlight(ReaderHighlight highlight) {
    ReaderAnnotation? annotation;
    for (final item in _annotations) {
      if (item.id == highlight.id) {
        annotation = item;
        break;
      }
    }
    if (annotation == null) return;
    unawaited(
      _editAnnotation(selection: annotation.selection, existing: annotation),
    );
  }

  Future<void> _editAnnotation({
    required ReaderSelection selection,
    ReaderAnnotation? existing,
  }) async {
    final input = TextEditingController(text: existing?.note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? '添加高亮或笔记' : '编辑笔记'),
        content: TextField(
          controller: input,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(hintText: '笔记内容可留空，只保留高亮'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    input.dispose();
    if (note == null || !mounted) return;
    final annotation = existing == null
        ? ReaderAnnotation(
            id: '${DateTime.now().microsecondsSinceEpoch}',
            selection: selection,
            note: note.trim(),
            colorValue: Theme.of(
              context,
            ).colorScheme.tertiaryContainer.toARGB32(),
          )
        : existing.withNote(note.trim());
    final next = [
      ..._annotations.where((item) => item.id != annotation.id),
      annotation,
    ];
    setState(() => _annotations = next);
    await _sessions.saveAnnotations(widget.record.id, next);
  }

  Future<void> _removeHighlight(ReaderHighlight highlight) async {
    final next = _annotations.where((item) => item.id != highlight.id).toList();
    if (mounted) setState(() => _annotations = next);
    await _sessions.saveAnnotations(widget.record.id, next);
  }

  Future<void> _showAnnotations() async {
    final controller = _controller;
    if (_annotations.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('还没有高亮或笔记')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _annotations.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final annotation = _annotations[index];
            return ListTile(
              title: Text(
                annotation.selection.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: annotation.note.isEmpty ? null : Text(annotation.note),
              onTap: () async {
                Navigator.pop(sheetContext);
                await controller?.goTo(annotation.selection.start);
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final format = widget.record.format == 'pdf'
        ? ReaderFormat.pdf
        : ReaderFormat.epub;
    return Scaffold(
      body: PapyrusReader(
        key: ValueKey(widget.record.id),
        document: ReaderDocument(
          id: widget.record.id,
          title: widget.record.name,
          format: format,
          loadBytes: () => _fileStore.readBytes(widget.record.path),
        ),
        initialLocator: _initialLocator,
        controller: controller,
        onBack: () => Navigator.of(context).maybePop(),
        onAnnotate: _addAnnotation,
        onNote: _addAnnotation,
        onEditHighlight: _editHighlight,
        onRemoveHighlight: (highlight) =>
            unawaited(_removeHighlight(highlight)),
        highlights: _annotations.map((item) => item.toHighlight()).toList(),
        theme: ReaderThemeData.fromTheme(Theme.of(context)),
        builders: ReaderUiBuilders(
          toolbarActions: (_, _) => [
            IconButton(
              tooltip: '高亮与笔记',
              onPressed: _showAnnotations,
              icon: Badge(
                isLabelVisible: _annotations.isNotEmpty,
                label: Text('${_annotations.length}'),
                child: const Icon(Icons.edit_note_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
