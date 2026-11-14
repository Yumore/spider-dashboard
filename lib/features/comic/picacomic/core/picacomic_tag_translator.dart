import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:dashboard/features/comic/picacomic/core/picacomic_search_suggestion.dart';
import 'package:dashboard/features/comic/picacomic/network/nhentai_tags.dart';
import 'package:flutter/services.dart';

/// Loads PicaComic tag dictionaries and provides locale-aware labels and search completions.
class PicacomicTagTranslator {
  PicacomicTagTranslator._();

  static const _simplifiedAsset = 'assets/picacomic/tags.json';
  static const _traditionalAsset = 'assets/picacomic/tags_tw.json';
  static const _namespaceOrder = [
    'male',
    'female',
    'parody',
    'character',
    'mixed',
    'artist',
    'group',
    'cosplayer',
    'other',
    'language',
    'reclass',
  ];
  static const _plainTagNamespaces = [
    'male',
    'female',
    'language',
    'parody',
    'character',
    'other',
    'mixed',
    'reclass',
    'cosplayer',
    'artist',
    'group',
  ];
  static const _namespaceAliases = {
    'artists': 'artist',
    'characters': 'character',
    'groups': 'group',
    'languages': 'language',
    'parodies': 'parody',
    'tags': 'tag',
    'categories': 'category',
  };

  static Future<void>? _loading;
  static Map<String, Map<String, String>>? _simplified;
  static Map<String, Map<String, String>>? _traditional;
  static final Map<String, List<String>> _categoryTags = {};
  static List<String>? _ehentaiSearchTags;
  static List<String>? _nhentaiSearchTags;
  static Map<String, List<String>>? _ehentaiTagsByFinalWord;
  static Map<String, List<String>>? _nhentaiTagsByFinalWord;
  static List<String>? _ehentaiFinalWords;
  static List<String>? _nhentaiFinalWords;

  static bool get isInitialized => _simplified != null && _traditional != null;

  /// Loads both locale dictionaries once so system locale changes take effect immediately.
  static Future<void> initialize() async {
    if (isInitialized) return;
    _loading ??= _loadDictionaries();
    try {
      await _loading;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  static Future<void> _loadDictionaries() async {
    final contents = await Future.wait([
      rootBundle.loadString(_simplifiedAsset),
      rootBundle.loadString(_traditionalAsset),
    ]);
    final simplified = _decodeDictionary(contents[0]);
    final traditional = _decodeDictionary(contents[1]);
    _simplified = simplified;
    _traditional = traditional;
    _categoryTags.clear();
    _ehentaiSearchTags = null;
    _nhentaiSearchTags = null;
    _ehentaiTagsByFinalWord = null;
    _nhentaiTagsByFinalWord = null;
    _ehentaiFinalWords = null;
    _nhentaiFinalWords = null;
  }

  static Map<String, Map<String, String>> _decodeDictionary(String contents) {
    final decoded = jsonDecode(contents) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        if (entry.value is Map)
          entry.key: {
            for (final value in (entry.value as Map).entries)
              value.key.toString(): value.value.toString(),
          },
    };
  }

  /// Returns the complete category vocabulary for a PicaComic namespace.
  static Iterable<String> tagsForNamespace(
    String namespace, {
    Iterable<String> fallback = const [],
  }) {
    final dictionary = _simplified?[namespace] ?? _traditional?[namespace];
    if (dictionary == null || dictionary.isEmpty) return fallback;
    return _categoryTags.putIfAbsent(namespace, () {
      final prefix = namespace == 'character' ? '' : '$namespace:';
      return List.unmodifiable(dictionary.keys.map((tag) => '$prefix$tag'));
    });
  }

  /// Translates a source category label when the active locale is Chinese.
  static String translateNamespace(String namespace, Locale locale) {
    if (!_isChinese(locale)) return namespace;
    final dictionary = _dictionaryFor(locale);
    final rows = dictionary['rows'] ?? const <String, String>{};
    final exact = rows[namespace] ?? rows[namespace.toLowerCase()];
    if (exact != null) return exact;

    final normalized = _normalizeNamespace(namespace);
    return rows[normalized] ?? namespace;
  }

  /// Translates a tag, optionally using its enclosing source category.
  static String translateTag(String tag, Locale locale, {String? namespace}) {
    if (!_isChinese(locale)) return tag;
    final dictionary = _dictionaryFor(locale);
    final alternatives = tag.split(RegExp(r'\s*\|\s*'));
    if (alternatives.length > 1) {
      for (final alternative in alternatives) {
        final translated = _lookupTag(alternative, dictionary, namespace);
        if (translated != null) return translated;
      }
      return tag;
    }
    return _lookupTag(tag, dictionary, namespace) ?? tag;
  }

  /// Builds bounded suggestions for sources that advertise tag completion.
  static List<PicacomicSearchSuggestion> suggestionsFor({
    required String sourceKey,
    required String query,
    required Locale locale,
    int limit = 12,
  }) {
    final trimmed = query.trimRight();
    if (query != trimmed) return const [];
    if (trimmed.isEmpty || trimmed.length < 2 || limit <= 0) return const [];

    final separator = trimmed.lastIndexOf(' ');
    final beforePartial = separator < 0
        ? ''
        : trimmed.substring(0, separator + 1);
    final partial = trimmed.substring(separator + 1).toLowerCase();
    if (partial.isEmpty) return const [];

    final candidates = switch (sourceKey) {
      'ehentai' => _eHentaiTags(),
      'nhentai' => _nHentaiTags(),
      _ => const <String>[],
    };
    if (candidates.isEmpty) return const [];

    final suggestions = <PicacomicSearchSuggestion>[];
    final seenQueries = <String>{};
    if (beforePartial.isNotEmpty) {
      _addContextualSuggestions(
        sourceKey: sourceKey,
        candidates: candidates,
        beforePartial: beforePartial,
        partial: partial,
        locale: locale,
        limit: limit,
        seenQueries: seenQueries,
        suggestions: suggestions,
      );
    }

    if (suggestions.length < limit) {
      final prefixIndex = _lowerBound(candidates, partial);
      for (
        var index = prefixIndex;
        index < candidates.length && suggestions.length < limit;
        index++
      ) {
        final candidate = candidates[index];
        if (!candidate.toLowerCase().startsWith(partial)) break;
        _addSuggestion(
          candidate: candidate,
          query: '$beforePartial$candidate',
          locale: locale,
          seenQueries: seenQueries,
          suggestions: suggestions,
        );
      }
    }
    return List.unmodifiable(suggestions);
  }

  static void _addContextualSuggestions({
    required String sourceKey,
    required List<String> candidates,
    required String beforePartial,
    required String partial,
    required Locale locale,
    required int limit,
    required Set<String> seenQueries,
    required List<PicacomicSearchSuggestion> suggestions,
  }) {
    final tagsByFinalWord = _finalWordIndex(sourceKey, candidates);
    final words = _finalWordKeys(sourceKey, tagsByFinalWord);
    final start = _lowerBound(words, partial);
    for (
      var index = start;
      index < words.length && suggestions.length < limit;
      index++
    ) {
      final finalWord = words[index];
      if (!finalWord.startsWith(partial)) break;
      for (final candidate in tagsByFinalWord[finalWord]!) {
        final wordStart = candidate.lastIndexOf(' ') + 1;
        if (wordStart == 0) continue;
        final precedingWords = candidate.substring(0, wordStart);
        final candidateFinalWord = candidate.substring(wordStart);
        if (!beforePartial.toLowerCase().endsWith(
          precedingWords.toLowerCase(),
        )) {
          continue;
        }
        _addSuggestion(
          candidate: candidate,
          query: '$beforePartial$candidateFinalWord',
          locale: locale,
          seenQueries: seenQueries,
          suggestions: suggestions,
        );
        if (suggestions.length >= limit) return;
      }
    }
  }

  static void _addSuggestion({
    required String candidate,
    required String query,
    required Locale locale,
    required Set<String> seenQueries,
    required List<PicacomicSearchSuggestion> suggestions,
  }) {
    if (!seenQueries.add(query)) return;
    suggestions.add(
      PicacomicSearchSuggestion(
        query: query,
        label: translateTag(candidate, locale),
      ),
    );
  }

  static List<String> _eHentaiTags() =>
      _ehentaiSearchTags ??= List.unmodifiable(
        [
          for (final namespace in _namespaceOrder)
            ...tagsForNamespace(namespace),
        ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      );

  static List<String> _nHentaiTags() =>
      _nhentaiSearchTags ??= List.unmodifiable(
        nhentaiTags.values.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      );

  static Map<String, List<String>> _finalWordIndex(
    String sourceKey,
    List<String> tags,
  ) {
    if (sourceKey == 'ehentai') {
      return _ehentaiTagsByFinalWord ??= _buildFinalWordIndex(tags);
    }
    return _nhentaiTagsByFinalWord ??= _buildFinalWordIndex(tags);
  }

  static List<String> _finalWordKeys(
    String sourceKey,
    Map<String, List<String>> index,
  ) {
    if (sourceKey == 'ehentai') {
      return _ehentaiFinalWords ??= List.unmodifiable(
        index.keys.toList()..sort(),
      );
    }
    return _nhentaiFinalWords ??= List.unmodifiable(
      index.keys.toList()..sort(),
    );
  }

  static Map<String, List<String>> _buildFinalWordIndex(List<String> tags) {
    final grouped = <String, List<String>>{};
    for (final tag in tags) {
      final key = tag.substring(tag.lastIndexOf(' ') + 1).toLowerCase();
      (grouped[key] ??= []).add(tag);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    });
  }

  static int _lowerBound(List<String> values, String prefix) {
    var low = 0;
    var high = values.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (values[middle].toLowerCase().compareTo(prefix) < 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  static String? _lookupTag(
    String rawTag,
    Map<String, Map<String, String>> dictionary,
    String? namespace,
  ) {
    final tag = rawTag.trim().toLowerCase();
    if (tag.isEmpty) return null;
    final colon = tag.indexOf(':');
    if (colon > 0) {
      final prefix = _normalizeNamespace(tag.substring(0, colon));
      final value = tag.substring(colon + 1).trim();
      final namespaced = dictionary[prefix]?[value];
      if (namespaced != null) return namespaced;
      return null;
    }

    if (namespace != null) {
      final normalized = _normalizeNamespace(namespace);
      final namespaced = dictionary[normalized]?[tag];
      if (namespaced != null) return namespaced;
      if (normalized != 'tag' && normalized != 'category') return null;
    }

    for (final candidateNamespace in _plainTagNamespaces) {
      final translated = dictionary[candidateNamespace]?[tag];
      if (translated != null) return translated;
    }
    return null;
  }

  static String _normalizeNamespace(String namespace) {
    final lower = namespace.trim().toLowerCase();
    return _namespaceAliases[lower] ?? lower;
  }

  static Map<String, Map<String, String>> _dictionaryFor(Locale locale) {
    if (_isTraditional(locale)) {
      return _traditional ?? _simplified ?? const {};
    }
    return _simplified ?? _traditional ?? const {};
  }

  static bool _isChinese(Locale locale) => locale.languageCode == 'zh';

  static bool _isTraditional(Locale locale) {
    final region = locale.countryCode?.toUpperCase();
    final script = locale.scriptCode?.toLowerCase();
    return region == 'TW' ||
        region == 'HK' ||
        region == 'MO' ||
        script == 'hant';
  }
}
