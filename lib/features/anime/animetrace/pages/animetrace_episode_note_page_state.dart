import 'dart:async';

import 'package:dashboard/app/platform/app_platform.dart';
import 'package:dashboard/features/anime/animetrace/animetrace_note_image.dart';
import 'package:dashboard/features/anime/animetrace/pages/animetrace_episode_note_page.dart';
import 'package:dashboard/features/anime/animetrace/store/animetrace_image_store.dart';
import 'package:dashboard/app/platform/app_local_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// State of [AnimeTraceEpisodeNotePage].
///
/// The note row is created on first open (`ensureNote`) so saving is a plain
/// update; images are copied into the user's local note folder and only the
/// relative path is stored, exactly like the source app.
class AnimeTraceEpisodeNotePageState extends State<AnimeTraceEpisodeNotePage> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  int _noteId = 0;
  String _noteRoot = '';
  List<AnimeTraceNoteImage> _images = const <AnimeTraceNoteImage>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final root = await widget.imageStore.noteImageRootDirPath();
      final noteId = await widget.episodeNoteDao.ensureNote(
        widget.anime,
        widget.episode,
      );
      final note = await widget.episodeNoteDao.loadNote(
        widget.anime,
        widget.episode,
      );
      if (!mounted) return;
      setState(() {
        _noteId = noteId;
        _noteRoot = root;
        _controller.text = note?.noteContent ?? '';
        _images = note?.relativeLocalImages ?? const <AnimeTraceNoteImage>[];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _reloadImages() async {
    final images = await widget.episodeNoteDao.getImages(_noteId);
    if (!mounted) return;
    setState(() => _images = images);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.episodeNoteDao.saveNoteContent(_noteId, _controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('笔记已保存')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addImage() async {
    if (!AppPlatform.supportsImagePicker || !AppPlatform.supportsFileSystem) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前平台暂不支持添加本地图片')));
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final relative = await widget.imageStore.saveNoteImage(picked.path);
      await widget.episodeNoteDao.addImage(
        _noteId,
        relativePath: relative,
        originName: picked.name,
      );
      await _reloadImages();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加图片失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeImage(AnimeTraceNoteImage image) async {
    await widget.episodeNoteDao.deleteImage(image.imageId);
    await widget.imageStore.deleteNoteImage(image.path, root: _noteRoot);
    await _reloadImages();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.episode.isRateEpisode
        ? '评分笔记'
        : '${widget.anime.animeName} · ${widget.episode.caption}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: '保存',
            icon: const Icon(Icons.save_outlined),
            onPressed: _loading || _error != null || _busy ? null : _save,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        tooltip: '添加本地图片',
        onPressed: _loading || _error != null ? null : _addImage,
        child: const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text('打开笔记失败：$error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(_load()),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        if (_noteRoot.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('尚未设置笔记图片文件夹，图片将保存到默认目录。'),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '写点什么…',
              ),
            ),
          ),
        ),
        if (_images.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final image = _images[index];
                final absolute = AnimeTraceImageStore.absolutePathOf(
                  image.path,
                  _noteRoot,
                );
                return Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: absolute.isEmpty
                          ? const SizedBox(width: 80, height: 80)
                          : Image(
                              image: AppLocalImage.provider(absolute),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 80,
                                height: 80,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: InkWell(
                        onTap: () => unawaited(_removeImage(image)),
                        child: const CircleAvatar(
                          radius: 10,
                          child: Icon(Icons.close, size: 12),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
