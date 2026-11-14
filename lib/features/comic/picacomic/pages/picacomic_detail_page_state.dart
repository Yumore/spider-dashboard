import 'package:cached_network_image/cached_network_image.dart';
import 'package:dashboard/features/comic/picacomic/controllers/picacomic_detail_controller.dart';
import 'package:dashboard/features/comic/picacomic/core/picacomic_tag_translator.dart';
import 'package:dashboard/features/comic/picacomic/pages/picacomic_detail_page.dart';
import 'package:dashboard/features/comic/picacomic/pages/picacomic_reader_page.dart';
import 'package:flutter/material.dart';

class PicacomicDetailPageState extends State<PicacomicDetailPage> {
  late final PicacomicDetailController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        PicacomicDetailController(
          sourceKey: widget.sourceKey,
          comicId: widget.comicId,
        );
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_controller.comic?.title ?? widget.title),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return IconButton(
                tooltip: _controller.favorite ? '取消收藏' : '收藏',
                onPressed: _controller.comic == null
                    ? null
                    : () => _controller.toggleFavorite(),
                icon: Icon(
                  _controller.favorite ? Icons.favorite : Icons.favorite_border,
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading && _controller.comic == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = _controller.error;
          if (error != null && _controller.comic == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _controller.load,
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          final comic = _controller.comic;
          if (comic == null) {
            return const Center(child: Text('暂无详情'));
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(comic.cover)),
              SliverToBoxAdapter(child: _info()),
              if (comic.tags.isNotEmpty) SliverToBoxAdapter(child: _tags()),
              SliverToBoxAdapter(child: _chaptersHeader()),
              SliverList.builder(
                itemCount: _controller.chapters.length,
                itemBuilder: (context, index) {
                  final chapter = _controller.chapters[index];
                  return ListTile(
                    dense: true,
                    leading: Text('${index + 1}'),
                    title: Text(chapter.value),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openReader(chapter.key, chapter.value),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String cover) {
    final url = cover.isNotEmpty ? cover : widget.cover;
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: url.isEmpty
                    ? const ColoredBox(color: Colors.black12)
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const ColoredBox(color: Colors.black12),
                      ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _controller.comic?.title ?? widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _controller.comic?.subTitle ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_controller.chapters.length} 章节',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info() {
    final description = _controller.comic?.description ?? '';
    if (description.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(description),
    );
  }

  Widget _tags() {
    final tags = _controller.comic?.tags ?? const <String, List<String>>{};
    final locale = Localizations.localeOf(context);
    final translate = const {
      'ehentai',
      'hitomi',
      'nhentai',
    }.contains(widget.sourceKey);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in tags.entries)
            if (entry.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${translate ? PicacomicTagTranslator.translateNamespace(entry.key, locale) : entry.key}:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    for (final tag in entry.value)
                      Chip(
                        label: Text(
                          translate
                              ? PicacomicTagTranslator.translateTag(
                                  tag,
                                  locale,
                                  namespace: entry.key,
                                )
                              : tag,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _chaptersHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Text('章节', style: Theme.of(context).textTheme.titleSmall),
    );
  }

  void _openReader(String chapterId, String chapterName) {
    final comic = _controller.comic;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PicacomicReaderPage(
          sourceKey: widget.sourceKey,
          comicId: widget.comicId,
          chapterId: chapterId,
          chapterName: chapterName,
          title: comic?.title ?? widget.title,
          cover: comic?.cover ?? widget.cover,
          chapterCount: _controller.chapters.length,
        ),
      ),
    );
  }
}
