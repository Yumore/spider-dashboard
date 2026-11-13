import 'package:dashboard/features/comic/picacomic/core/base_comic.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_source.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_source_registry.dart';
import 'package:dashboard/features/comic/picacomic/core/search_options.dart';
import 'package:dashboard/features/comic/picacomic/core/search_page_data.dart';
import 'package:flutter/foundation.dart';

/// Controller of the picacomic search screen.
///
/// Ports the search contract of PicaComic lib/pages/pre_search_page.dart and
/// lib/pages/search_result_page.dart: one option group per `SearchOptions`,
/// each group's first entry is the default, `loadPage(keyword, page, options)`
/// returns the comics and `Res.subData` carries the number of remaining pages.
/// The first result page is also what feeds `appdata.searchHistory`, which the
/// host does not persist (out of the ported scope).
class PicacomicSearchController extends ChangeNotifier {
  static const Map<String, String> languageFilters = {
    '': '语言：全部',
    'chinese': '语言：中文',
    'english': '语言：English',
    'japanese': '语言：日本語',
  };

  PicacomicSearchController({List<ComicSource>? sources})
    : sources =
          sources ??
          ComicSourceRegistry.sources
              .where((source) => source.searchPageData != null)
              .toList(growable: false);

  final List<ComicSource> sources;

  int _sourceIndex = 0;
  String _keyword = '';
  List<String> _selectedOptions = const [];
  List<BaseComic> _results = const [];
  bool _loading = false;
  bool _disposed = false;
  bool _searched = false;
  String _languageFilter = '';
  String? _error;
  int _page = 1;
  int? _maxPage;
  int _requestGeneration = 0;

  int get sourceIndex => _sourceIndex;

  ComicSource? get source => sources.isEmpty
      ? null
      : sources[_sourceIndex.clamp(0, sources.length - 1)];

  SearchPageData? get searchPageData => source?.searchPageData;

  List<SearchOptions> get searchOptions =>
      searchPageData?.searchOptions ?? const <SearchOptions>[];

  String get keyword => _keyword;

  List<String> get selectedOptions => List.unmodifiable(_selectedOptions);

  List<BaseComic> get results => List.unmodifiable(_results);

  bool get loading => _loading;

  bool get searched => _searched;

  String get languageFilter => _languageFilter;

  String? get error => _error;

  int get page => _page;

  bool get hasMore => _maxPage == null || _page < _maxPage!;

  void selectSource(int index) {
    if (index < 0 || index >= sources.length || index == _sourceIndex) return;
    _sourceIndex = index;
    _languageFilter = '';
    _selectedOptions = [
      for (final option in searchOptions) option.defaultValue,
    ];
    _resetResults();
    _searched = false;
    _notify();
  }

  /// Replaces one option group's selection (index aligned with
  /// [searchOptions]).
  Future<void> selectOption(int group, String value) async {
    if (group < 0 || group >= searchOptions.length) return;
    final options = [..._selectedOptions];
    while (options.length <= group) {
      options.add(searchOptions[options.length].defaultValue);
    }
    if (options[group] == value) return;
    options[group] = value;
    _selectedOptions = options;
    if (!_searched) {
      _notify();
      return;
    }
    _resetResults();
    await _load(1, replace: true);
  }

  /// Applies the selected language to sources that advertise language search.
  /// An explicit `language:` term in the query always takes precedence.
  Future<void> selectLanguageFilter(String value) async {
    if (!languageFilters.containsKey(value) || value == _languageFilter) return;
    _languageFilter = value;
    if (!_searched) {
      _notify();
      return;
    }
    _resetResults();
    await _load(1, replace: true);
  }

  /// Runs a fresh search and resets paging.
  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      _error = 'Empty keyword';
      _notify();
      return;
    }
    _keyword = trimmed;
    _selectedOptions = [
      for (var index = 0; index < searchOptions.length; index++)
        index < _selectedOptions.length
            ? _selectedOptions[index]
            : searchOptions[index].defaultValue,
    ];
    _resetResults();
    _searched = true;
    await _load(1, replace: true);
  }

  Future<void> loadMore() {
    if (!hasMore || !_searched) return Future.value();
    return _load(_page + 1, replace: false);
  }

  Future<void> _load(int page, {required bool replace}) async {
    final data = searchPageData;
    final loader = data?.loadPage;
    if (loader == null) {
      _error = 'Source has no search loader';
      _notify();
      return;
    }
    final generation = ++_requestGeneration;
    _loading = true;
    _error = null;
    _notify();
    try {
      final res = await loader(
        _queryWithLanguageFilter(),
        page,
        _selectedOptions,
      );
      if (generation != _requestGeneration) return;
      if (res.error) {
        _error = res.errorMessageWithoutNull;
      } else {
        _results = replace ? res.data : [..._results, ...res.data];
        _maxPage = res.subData is int ? res.subData as int : null;
        _page = page;
      }
    } catch (e) {
      if (generation != _requestGeneration) return;
      _error = '$e';
    }
    if (generation != _requestGeneration) return;
    _loading = false;
    _notify();
  }

  String _queryWithLanguageFilter() {
    final data = searchPageData;
    final filter = _languageFilter;
    if (data?.enableLanguageFilter != true || filter.isEmpty) return _keyword;
    if (RegExp(r'(?:^|\s)language:', caseSensitive: false).hasMatch(_keyword)) {
      return _keyword;
    }
    return '$_keyword language:$filter';
  }

  void _resetResults() {
    _requestGeneration++;
    _results = const [];
    _loading = false;
    _page = 1;
    _maxPage = null;
    _error = null;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
