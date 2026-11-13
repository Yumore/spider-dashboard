import 'package:dashboard/features/comic/picacomic/core/base_category_part.dart';
import 'package:dashboard/features/comic/picacomic/core/base_comic.dart';
import 'package:dashboard/features/comic/picacomic/core/category_data.dart';
import 'package:dashboard/features/comic/picacomic/core/category_comics_data.dart';
import 'package:dashboard/features/comic/picacomic/core/category_comics_options.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_source.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_source_registry.dart';
import 'package:flutter/foundation.dart';

/// Controller of the picacomic category screen.
///
/// Ports the category flow of PicaComic lib/pages/category_page.dart +
/// lib/pages/category_comics_page.dart: a source exposes `CategoryData` with
/// parts (`FixedCategoryPart` / `RandomCategoryPart` /
/// `RandomCategoryPartWithRuntimeData`), clicking a category calls
/// `CategoryComicsData.load(category, param, options, page)` and a ranking entry
/// (when [CategoryData.enableRankingPage]) calls `RankingData.load(option, page)`.
///
/// Deviation: PicaComic's page turned `categoryType == 'search_with_namespace'`
/// into a `namespace:tag` keyword before searching; the ported e-hentai tag
/// lists already carry their `namespace:` prefix, so the controller passes the
/// category through unchanged.
class PicacomicCategoryController extends ChangeNotifier {
  PicacomicCategoryController({List<ComicSource>? sources})
    : sources =
          sources ??
          ComicSourceRegistry.sources
              .where((source) => source.categoryComicsData != null)
              .toList(growable: false);

  final List<ComicSource> sources;

  int _sourceIndex = 0;
  int _partIndex = 0;
  int _categoryIndex = 0;
  List<String> _categories = const [];
  List<String?> _params = const [];
  List<String> _selectedOptions = const [];
  bool _ranking = false;
  String? _rankingOption;
  List<BaseComic> _results = const [];
  bool _loading = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  String? _error;
  int _page = 1;
  int? _maxPage;

  int get sourceIndex => _sourceIndex;

  ComicSource? get source => sources.isEmpty
      ? null
      : sources[_sourceIndex.clamp(0, sources.length - 1)];

  CategoryData? get categoryData => source?.categoryData;

  CategoryComicsData? get categoryComicsData => source?.categoryComicsData;

  List<BaseCategoryPart> get parts => categoryData?.categories ?? const [];

  int get partIndex => _partIndex;

  BaseCategoryPart? get part =>
      parts.isEmpty ? null : parts[_partIndex.clamp(0, parts.length - 1)];

  List<String> get categories => List.unmodifiable(_categories);

  int get categoryIndex => _categoryIndex;

  String? get category =>
      _categories.isEmpty ? null : _categories[_categoryIndex];

  String? get categoryParam => _params.isEmpty ? null : _params[_categoryIndex];

  /// The option groups that apply to the selected category.
  List<CategoryComicsOptions> get applicableOptions {
    final data = categoryComicsData;
    final name = category;
    if (data == null || name == null) return const [];
    return data.applicableOptions(name);
  }

  List<String> get selectedOptions => List.unmodifiable(_selectedOptions);

  bool get ranking => _ranking;

  Map<String, String> get rankingOptions =>
      categoryComicsData?.rankingData?.options ?? const {};

  String? get rankingOption => _rankingOption;

  List<BaseComic> get results => List.unmodifiable(_results);

  bool get loading => _loading;

  String? get error => _error;

  int get page => _page;

  bool get hasMore => _maxPage == null || _page < _maxPage!;

  /// Switches source, resolving the first part's categories.
  Future<void> selectSource(int index) async {
    if (index < 0 || index >= sources.length || index == _sourceIndex) return;
    _sourceIndex = index;
    await selectPart(0);
  }

  /// Resolves a part's categories. Random parts re-roll on every call and
  /// runtime parts evaluate `loadTags()` (category.dart:60-120).
  Future<void> selectPart(int index) async {
    if (index < 0 || index >= parts.length) return;
    _partIndex = index;
    final selected = parts[index];
    _categories = selected.categories;
    _params = [
      for (var i = 0; i < _categories.length; i++)
        (selected.categoryParams != null && i < selected.categoryParams!.length)
            ? selected.categoryParams![i]
            : null,
    ];
    _categoryIndex = 0;
    _ranking = false;
    _resetSelectedOptions();
    await load();
  }

  Future<void> selectCategory(int index) async {
    if (index < 0 || index >= _categories.length || index == _categoryIndex) {
      return;
    }
    _categoryIndex = index;
    _ranking = false;
    _resetSelectedOptions();
    await load();
  }

  /// Loads a category that is not part of the selected part, e.g. the
  /// `category:random` / `category:latest` "view more" links of an explore part.
  Future<void> loadSpecific(String category, [String? param]) async {
    _categories = [category];
    _params = [param];
    _categoryIndex = 0;
    _ranking = false;
    _resetSelectedOptions();
    await load();
  }

  Future<void> selectOption(int group, String value) async {
    final availableOptions = applicableOptions;
    if (group < 0 || group >= availableOptions.length) return;
    final options = [..._selectedOptions];
    while (options.length <= group) {
      options.add(availableOptions[options.length].defaultValue);
    }
    if (options[group] == value) return;
    options[group] = value;
    _selectedOptions = options;
    await _load(1, replace: true);
  }

  Future<void> selectRankingOption(String option) async {
    _rankingOption = option;
    _ranking = true;
    await load();
  }

  Future<void> load() => _load(1, replace: true);

  Future<void> loadMore() {
    if (!hasMore || _loading) return Future.value();
    return _load(_page + 1, replace: false);
  }

  void _resetSelectedOptions() {
    _selectedOptions = [
      for (final option in applicableOptions) option.defaultValue,
    ];
  }

  Future<void> _load(int page, {required bool replace}) async {
    final data = categoryComicsData;
    if (data == null) {
      _error = 'Source has no categoryComicsData';
      _notify();
      return;
    }
    final generation = ++_loadGeneration;
    _loading = true;
    _error = null;
    _notify();
    try {
      final rankingData = data.rankingData;
      final res = _ranking && rankingData != null
          ? await rankingData.load(
              _rankingOption ?? rankingData.options.keys.first,
              page,
            )
          : await data.load(
              category ?? '',
              categoryParam,
              _selectedOptions,
              page,
            );
      if (generation != _loadGeneration) return;
      if (res.error) {
        _error = res.errorMessageWithoutNull;
      } else {
        _results = replace ? res.data : [..._results, ...res.data];
        _maxPage = res.subData is int ? res.subData as int : null;
        _page = page;
      }
    } catch (e) {
      if (generation != _loadGeneration) return;
      _error = '$e';
    }
    if (generation != _loadGeneration) return;
    _loading = false;
    _notify();
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
