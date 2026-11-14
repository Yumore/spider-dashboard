import 'package:dashboard/features/comic/picacomic/controllers/picacomic_category_controller.dart';
import 'package:dashboard/features/comic/picacomic/core/category_comics_options.dart';
import 'package:dashboard/features/comic/picacomic/core/picacomic_tag_translator.dart';
import 'package:dashboard/features/comic/picacomic/pages/picacomic_category_page.dart';
import 'package:dashboard/features/comic/picacomic/pages/picacomic_comic_tile.dart';
import 'package:dashboard/features/comic/picacomic/pages/picacomic_detail_page.dart';
import 'package:flutter/material.dart';

class PicacomicCategoryPageState extends State<PicacomicCategoryPage> {
  late final PicacomicCategoryController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? PicacomicCategoryController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final sourceKey = widget.sourceKey;
    if (sourceKey != null) {
      final index = _controller.sources.indexWhere(
        (source) => source.key == sourceKey,
      );
      if (index >= 0 && index != _controller.sourceIndex) {
        await _controller.selectSource(index);
      }
    }
    final category = widget.initialCategory;
    if (category != null) {
      await _controller.loadSpecific(category, widget.initialParam);
    } else if (_controller.results.isEmpty && !_controller.loading) {
      await _controller.selectPart(0);
    }
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
        title: Text(_controller.source?.categoryData?.title ?? '分类'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _partsBar(),
              _categoriesBar(),
              _optionsBar(),
              if (_controller.loading)
                const LinearProgressIndicator(minHeight: 2),
              if (_controller.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _controller.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(child: _results()),
            ],
          );
        },
      ),
    );
  }

  Widget _partsBar() {
    final parts = _controller.parts;
    if (parts.length <= 1) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);
    final translate = _supportsTagTranslation;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (var i = 0; i < parts.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  translate
                      ? PicacomicTagTranslator.translateNamespace(
                          parts[i].title,
                          locale,
                        )
                      : parts[i].title,
                ),
                selected: _controller.partIndex == i,
                onSelected: (_) => _controller.selectPart(i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoriesBar() {
    final categories = _controller.categories;
    if (categories.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);
    final translate = _supportsTagTranslation;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  translate
                      ? PicacomicTagTranslator.translateTag(
                          categories[i],
                          locale,
                        )
                      : categories[i],
                ),
                selected: _controller.categoryIndex == i,
                onSelected: (_) => _controller.selectCategory(i),
              ),
            ),
        ],
      ),
    );
  }

  bool get _supportsTagTranslation =>
      const {'ehentai', 'nhentai'}.contains(_controller.source?.key);

  Widget _optionsBar() {
    final options = _controller.ranking
        ? const <CategoryComicsOptions>[]
        : _controller.applicableOptions;
    final ranking = _controller.rankingOptions;
    final enableRanking = _controller.categoryData?.enableRankingPage ?? false;
    if (options.isEmpty && !enableRanking) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (var group = 0; group < options.length; group++)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _optionDropdown(options[group], group),
            ),
          if (enableRanking && ranking.isNotEmpty)
            DropdownButton<String>(
              value: _controller.rankingOption,
              hint: const Text('排行'),
              items: [
                for (final entry in ranking.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) _controller.selectRankingOption(value);
              },
            ),
        ],
      ),
    );
  }

  Widget _optionDropdown(CategoryComicsOptions option, int group) {
    return DropdownButton<String>(
      value: _controller.selectedOptions.length > group
          ? _controller.selectedOptions[group]
          : option.defaultValue,
      items: [
        for (final entry in option.options.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (value) {
        if (value != null) _controller.selectOption(group, value);
      },
    );
  }

  Widget _results() {
    if (_controller.results.isEmpty && !_controller.loading) {
      return const Center(child: Text('暂无内容'));
    }
    final source = _controller.source;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 400) {
          _controller.loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.58,
        ),
        itemCount: _controller.results.length,
        itemBuilder: (context, index) {
          final comic = _controller.results[index];
          return PicacomicComicTile(
            comic: comic,
            onTap: () {
              if (source == null) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PicacomicDetailPage(
                    sourceKey: source.key,
                    comicId: comic.id,
                    title: comic.title,
                    cover: comic.cover,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
