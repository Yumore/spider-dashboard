import 'package:dashboard/features/comic/picacomic/controllers/picacomic_search_controller.dart';
import 'package:dashboard/features/comic/picacomic/core/picacomic_search_suggestion.dart';
import 'package:dashboard/features/comic/picacomic/core/picacomic_tag_translator.dart';
import 'package:dashboard/features/comic/picacomic/pages/picacomic_comic_tile.dart';
import 'package:dashboard/features/comic/picacomic/pages/picacomic_detail_page.dart';
import 'package:dashboard/features/comic/picacomic/pages/picacomic_search_page.dart';
import 'package:flutter/material.dart';

class PicacomicSearchPageState extends State<PicacomicSearchPage> {
  late final PicacomicSearchController _controller;
  late final bool _ownsController;
  final TextEditingController _keyword = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? PicacomicSearchController();
    final sourceKey = widget.sourceKey;
    if (sourceKey != null) {
      final index = _controller.sources.indexWhere(
        (source) => source.key == sourceKey,
      );
      if (index >= 0) _controller.selectSource(index);
    }
    final keyword = widget.initialKeyword;
    if (keyword != null && keyword.isNotEmpty) {
      _keyword.text = keyword;
      _controller.search(keyword);
    }
  }

  @override
  void dispose() {
    _keyword.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(child: _searchField(context)),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _controller.search(_keyword.text),
                      child: const Text('搜索'),
                    ),
                  ],
                ),
              ),
              _options(),
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

  Widget _searchField(BuildContext context) {
    final source = _controller.source;
    final suggestionsEnabled =
        _controller.searchPageData?.enableTagsSuggestions ?? false;
    final locale = Localizations.localeOf(context);
    return RawAutocomplete<PicacomicSearchSuggestion>(
      key: ValueKey(source?.key),
      textEditingController: _keyword,
      displayStringForOption: (suggestion) => suggestion.query,
      optionsBuilder: (value) {
        if (!suggestionsEnabled || source == null) {
          return const <PicacomicSearchSuggestion>[];
        }
        return PicacomicTagTranslator.suggestionsFor(
          sourceKey: source.key,
          query: value.text,
          locale: locale,
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            onFieldSubmitted();
            _controller.search(_keyword.text);
          },
          decoration: const InputDecoration(
            hintText: '关键字',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final values = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: values.length,
                itemBuilder: (context, index) {
                  final suggestion = values[index];
                  final highlightedIndex = AutocompleteHighlightedOption.of(
                    context,
                  );
                  return ListTile(
                    dense: true,
                    selected: index == highlightedIndex,
                    title: Text(suggestion.label),
                    subtitle: suggestion.label == suggestion.query
                        ? null
                        : Text(suggestion.query),
                    onTap: () => onSelected(suggestion),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _options() {
    final source = _controller.source;
    if (source == null) return const SizedBox.shrink();
    final groups = _controller.searchOptions;
    final showLanguageFilter =
        _controller.searchPageData?.enableLanguageFilter ?? false;
    if (groups.isEmpty && !showLanguageFilter) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (var group = 0; group < groups.length; group++)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DropdownButton<String>(
                value: _controller.selectedOptions.length > group
                    ? _controller.selectedOptions[group]
                    : groups[group].defaultValue,
                hint: Text(groups[group].label),
                items: [
                  for (final entry in groups[group].options.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _controller.selectOption(group, value);
                },
              ),
            ),
          if (showLanguageFilter)
            DropdownButton<String>(
              value: _controller.languageFilter,
              items: [
                for (final entry
                    in PicacomicSearchController.languageFilters.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) {
                  _controller.selectLanguageFilter(value);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _results() {
    if (!_controller.searched) {
      return const Center(child: Text('输入关键字开始搜索'));
    }
    if (_controller.results.isEmpty && !_controller.loading) {
      return const Center(child: Text('没有结果'));
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
