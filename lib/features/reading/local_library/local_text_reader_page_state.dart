import 'dart:async';
import 'dart:typed_data';

import 'package:dashboard/features/reading/local_library/local_reading_file_store.dart';
import 'package:dashboard/features/reading/local_library/local_text_document_decoder.dart';
import 'package:dashboard/features/reading/local_library/local_text_reader_page.dart';
import 'package:dashboard/features/reading/local_library/local_text_reading_progress_repository.dart';
import 'package:flutter/material.dart';

class LocalTextReaderPageState extends State<LocalTextReaderPage> {
  final LocalReadingFileStore _fileStore = LocalReadingFileStore();
  final LocalTextDocumentDecoder _decoder = const LocalTextDocumentDecoder();
  final LocalTextReadingProgressRepository _progress =
      LocalTextReadingProgressRepository();

  ScrollController? _scrollController;
  Timer? _saveTimer;
  String? _text;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final values = await Future.wait<Object>([
        _fileStore.readBytes(widget.record.path),
        _progress.loadOffset(widget.record.id),
      ]);
      final bytes = values[0] as Uint8List;
      final offset = values[1] as double;
      final content = _decoder.decode(bytes);
      final controller = ScrollController(initialScrollOffset: offset);
      controller.addListener(_scheduleProgressSave);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _text = content;
        _scrollController = controller;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _scheduleProgressSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveProgress);
  }

  void _saveProgress() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    unawaited(_progress.saveOffset(widget.record.id, controller.offset));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _text;
    final controller = _scrollController;
    return Scaffold(
      appBar: AppBar(title: Text(widget.record.name)),
      body: _error != null
          ? Center(child: Text('无法打开文本：$_error'))
          : content == null || controller == null
          ? const Center(child: CircularProgressIndicator())
          : SelectionArea(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                child: Text(
                  content,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.8),
                ),
              ),
            ),
    );
  }
}
