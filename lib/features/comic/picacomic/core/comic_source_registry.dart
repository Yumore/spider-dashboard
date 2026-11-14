import 'package:dashboard/features/comic/picacomic/core/comic_source.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_source_loader.dart';
import 'package:dashboard/features/comic/picacomic/core/history_type.dart';
import 'package:dashboard/features/comic/picacomic/core/picacomic_tag_translator.dart';
import 'package:dashboard/features/comic/picacomic/sources/ehentai_source.dart';
import 'package:dashboard/features/comic/picacomic/sources/hitomi_source.dart';
import 'package:dashboard/features/comic/picacomic/sources/htmanga_source.dart';
import 'package:dashboard/features/comic/picacomic/sources/jm_source.dart';
import 'package:dashboard/features/comic/picacomic/sources/nhentai_source.dart';
import 'package:dashboard/features/comic/picacomic/sources/picacg_source.dart';

/// Ports PicaComic's static `ComicSource.sources` registry and `init()`.
class ComicSourceRegistry {
  ComicSourceRegistry._();

  static final List<ComicSource> _sources = [];

  /// Registered sources, in registration order.
  static List<ComicSource> get sources => List.unmodifiable(_sources);

  /// The six shipped sources, matching PicaComic's `ComicSource.builtIn`.
  static List<ComicSource> get builtInSources => [
    picacgSource,
    ehentaiSource,
    jmSource,
    hitomiSource,
    htMangaSource,
    nhentaiSource,
  ];

  /// Error thrown by the last user-source load, if any.
  static Object? lastLoadError;

  /// Errors loading individual bundled sources; the source remains registered.
  static final Map<String, Object> sourceInitializationErrors = {};

  /// Error loading the optional localized tag dictionaries.
  static Object? tagDictionaryLoadError;

  static ComicSource? find(String key) {
    for (final source in _sources) {
      if (source.key == key) return source;
    }
    return null;
  }

  static ComicSource? fromIntKey(int key) {
    for (final source in _sources) {
      if (source.key.hashCode == key) return source;
    }
    return null;
  }

  /// Resolves the source owning [type]; built-in slots map by name, other
  /// values fall back to the key hash code used by user sources.
  static ComicSource? fromHistoryType(HistoryType type) {
    final name = HistoryType.nameOf(type.value);
    if (name != null) return find(name);
    return fromIntKey(type.value);
  }

  static ComicSource require(String key) {
    final source = find(key);
    if (source == null) {
      throw StateError('Unknown comic source: $key');
    }
    return source;
  }

  /// Registers the enabled built-in sources, then any user sources supplied by
  /// [userSourceLoader]. Mirrors PicaComic's `ComicSource.init()`.
  static Future<void> init({
    Iterable<String>? enabledKeys,
    ComicSourceLoader? userSourceLoader,
  }) async {
    _sources.clear();
    lastLoadError = null;
    sourceInitializationErrors.clear();
    tagDictionaryLoadError = null;

    try {
      await PicacomicTagTranslator.initialize();
    } catch (error) {
      tagDictionaryLoadError = error;
    }

    for (final source in builtInSources) {
      if (enabledKeys != null && !enabledKeys.contains(source.key)) continue;
      _sources.add(source);
      try {
        await source.loadData();
        final initData = source.initData;
        if (initData != null) await initData(source);
      } catch (error) {
        sourceInitializationErrors[source.key] = error;
      }
    }
    if (userSourceLoader != null) {
      try {
        _sources.addAll(await userSourceLoader.load());
      } catch (error) {
        lastLoadError = error;
      }
    }
  }

  static Future<void> reload({
    Iterable<String>? enabledKeys,
    ComicSourceLoader? userSourceLoader,
  }) async {
    await init(enabledKeys: enabledKeys, userSourceLoader: userSourceLoader);
  }

  /// Registers [source] directly; used by tests and by user-source loaders.
  static void register(ComicSource source) {
    if (_sources.any((element) => element.key == source.key)) return;
    _sources.add(source);
  }

  static void unregister(String key) {
    _sources.removeWhere((element) => element.key == key);
  }

  static void clear() {
    _sources.clear();
  }
}
