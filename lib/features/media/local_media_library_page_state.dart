import 'dart:async';
import 'dart:io';

import 'package:dashboard/features/media/local_media_library_page.dart';
import 'package:dashboard/features/media/local_media_library_store.dart';
import 'package:dashboard/features/media/media_playback_page.dart';
import 'package:dashboard/features/media/media_stream_source.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Imports, validates, persists and plays local video files selected by the user.
class LocalMediaLibraryPageState extends State<LocalMediaLibraryPage> {
  final LocalMediaLibraryStore _store = LocalMediaLibraryStore();
  List<String> _paths = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final saved = await _store.load();
      final exists = await Future.wait(
        saved.map((entry) => File(entry).exists()),
      );
      final available = [
        for (var index = 0; index < saved.length; index++)
          if (exists[index]) saved[index],
      ];
      if (!mounted) return;
      setState(() {
        _paths = available;
        _loading = false;
      });
      if (available.length != saved.length) await _store.save(available);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _import() async {
    if (_loading) return;
    final copiedPaths = <String>[];
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(type: FileType.video);
      if (!mounted) return;
      if (result.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final supportDirectory = await getApplicationSupportDirectory();
      final mediaDirectory = Directory(
        path.join(supportDirectory.path, 'dashboard_local_media'),
      );
      await mediaDirectory.create(recursive: true);
      final paths = <String>{..._paths};
      for (final file in result) {
        final sourcePath = file.path;
        if (sourcePath == null || sourcePath.isEmpty) {
          continue;
        }
        if (!await File(sourcePath).exists()) continue;
        if (!_supported(sourcePath)) continue;
        final copiedPath = await _copyIntoLibrary(sourcePath, mediaDirectory);
        copiedPaths.add(copiedPath);
        paths.add(copiedPath);
      }
      final next = paths.toList(growable: false);
      await _store.save(next);
      if (mounted) {
        setState(() {
          _paths = next;
          _loading = false;
        });
      }
    } catch (error) {
      for (final copiedPath in copiedPaths) {
        try {
          await File(copiedPath).delete();
        } on FileSystemException {
          // Keep the original import error visible; cleanup is best effort.
        }
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _remove(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
      final next = _paths
          .where((entry) => entry != filePath)
          .toList(growable: false);
      await _store.save(next);
      if (mounted) setState(() => _paths = next);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<String> _copyIntoLibrary(
    String sourcePath,
    Directory directory,
  ) async {
    final filename = path.basename(sourcePath);
    final extension = path.extension(filename);
    final basename = path.basenameWithoutExtension(filename);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    var suffix = 0;
    late String destinationPath;
    do {
      final collisionSuffix = suffix == 0 ? '' : '_$suffix';
      destinationPath = path.join(
        directory.path,
        '${basename}_$timestamp$collisionSuffix$extension',
      );
      suffix++;
    } while (await File(destinationPath).exists());
    await File(sourcePath).copy(destinationPath);
    return destinationPath;
  }

  Future<void> _play(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      await _remove(filePath);
      if (mounted) setState(() => _error = '本地文件已不存在，已从列表移除');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaPlaybackPage(
          title: path.basenameWithoutExtension(filePath),
          sources: [MediaStreamSource(label: '本地文件', url: Uri.file(filePath))],
        ),
      ),
    );
  }

  bool _supported(String value) => const {
    '.mp4',
    '.m4v',
    '.mkv',
    '.mov',
    '.avi',
    '.webm',
    '.ts',
    '.mpg',
    '.mpeg',
    '.wmv',
    '.flv',
  }.contains(path.extension(value).toLowerCase());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('本地媒体库'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _import,
          icon: const Icon(Icons.add),
          tooltip: '导入本地视频',
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('导入本地视频'),
                  subtitle: const Text('选择的视频会复制到应用媒体库，确保后续仍可访问；这会占用设备存储空间。'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _loading ? null : _import,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_paths.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: Text('尚未导入本地视频')),
                ),
              for (final filePath in _paths)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.movie_outlined),
                    title: Text(
                      path.basename(filePath),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: const Text('已复制到应用媒体库 · 点击播放'),
                    onTap: () => _play(filePath),
                    trailing: IconButton(
                      onPressed: () => _remove(filePath),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '从媒体库移除',
                    ),
                  ),
                ),
            ],
          ),
  );
}
