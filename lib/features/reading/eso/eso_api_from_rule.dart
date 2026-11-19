import 'package:dashboard/features/reading/eso/eso_analyze_url.dart';
import 'package:dashboard/features/reading/eso/eso_analyzer_manager.dart';
import 'package:dashboard/features/reading/eso/eso_api.dart';
import 'package:dashboard/features/reading/eso/eso_api_const.dart';
import 'package:dashboard/features/reading/eso/eso_chapter_item.dart';
import 'package:dashboard/features/reading/eso/eso_decode_body.dart';
import 'package:dashboard/features/reading/eso/eso_discover_map.dart';
import 'package:dashboard/features/reading/eso/eso_discover_pair.dart';
import 'package:dashboard/features/reading/eso/eso_http_client.dart';
import 'package:dashboard/features/reading/eso/eso_rule.dart';
import 'package:dashboard/features/reading/eso/eso_rule_exception.dart';
import 'package:dashboard/features/reading/eso/eso_search_item.dart';

/// 由书源规则驱动的实现（移植 eso `lib/api/api_from_rule.dart` 的 `APIFromRUle`）。
///
/// 与原实现的差异：`JSEngine.setEnvironment / evaluate` 调用被移除（宿主没有
/// JS 引擎，遇到 `@js:` 规则时 [EsoAnalyzeUrl] 直接抛 [EsoRuleException]）；
/// 宿主也没有 toast，正文解析失败时不再提示，但保留原来的抛出/吞掉分支。
class EsoApiFromRule implements EsoApi {
  EsoApiFromRule(this.rule, {EsoHttpClient? client})
      : _client = client ?? EsoHttpClient() {
    _origin = rule.name;
    _originTag = rule.id;
    _ruleContentType = rule.contentType;
  }

  final EsoRule rule;
  final EsoHttpClient _client;

  late String _origin;
  late String _originTag;
  late int _ruleContentType;

  final EsoDecodeBody _decodeBody = EsoDecodeBody();

  /// 下一页地址缓存：`{当前地址: 下一页地址}`（源实现是静态的，这里保持一致）。
  static Map<String, String>? _nextUrl;

  static Map<String, String>? get nextUrl => _nextUrl;

  static void setNextUrl(String url, String? next) {
    if (next == null) {
      _nextUrl?.remove(url);
      return;
    }
    _nextUrl ??= <String, String>{};
    _nextUrl![url] = next;
  }

  static void clearNextUrl() {
    _nextUrl?.clear();
  }

  /// 目录翻页的下一页地址。
  static String? chapterNextUrl;

  @override
  String get origin => _origin;

  @override
  String get originTag => _originTag;

  @override
  int get ruleContentType => _ruleContentType;

  String? checkString(String? s) => s != null && s.isNotEmpty ? s : null;

  EsoAnalyzerManager _analyzer(dynamic content) =>
      EsoAnalyzerManager(content, host: rule.host);

  @override
  Future<List<EsoSearchItem>> discover(
      Map<String, EsoDiscoverPair> params, int page, int pageSize) async {
    if (params.isEmpty) return <EsoSearchItem>[];
    final hasNextUrlRule = rule.discoverNextUrl.isNotEmpty;
    String? discoverRule;
    final url = params.values.first.value;
    if (page == 1) {
      discoverRule = url;
    } else if (hasNextUrlRule && page > 1) {
      final next = _nextUrl?[url];
      if (next != null && next.isNotEmpty) {
        discoverRule = next;
      }
    } else if (url.contains(EsoApiConst.pagePattern)) {
      discoverRule = url;
    }
    if (discoverRule == null) {
      return <EsoSearchItem>[];
    }
    var discoverUrl = '';
    var body = '';
    if (discoverRule != 'null') {
      final res = await EsoAnalyzeUrl.urlRuleParser(
        discoverRule,
        rule,
        _client,
        page: page,
        pageSize: pageSize,
      );
      if (res.contentLength == 0) {
        return <EsoSearchItem>[];
      }
      discoverUrl = res.request?.url.toString() ?? '';
      body = _decodeBody.decode(res.bodyBytes, res.headers['content-type']);
    }
    final bodyAnalyzer = _analyzer(body);
    if (hasNextUrlRule) {
      setNextUrl(url, bodyAnalyzer.getString(rule.discoverNextUrl));
    }
    final list = bodyAnalyzer.getElements(rule.discoverList);
    final result = <EsoSearchItem>[];
    for (final item in list) {
      final analyzer = _analyzer(item);
      final tag = analyzer.getString(rule.discoverTags);
      var tags = <String>[];
      if (tag.trim().isNotEmpty) {
        tags = tag.split(EsoApiConst.tagsSplitRegExp)
          ..removeWhere((tag) => tag.isEmpty);
      }
      result.add(EsoSearchItem(
        searchUrl: discoverUrl,
        cover: analyzer.getString(rule.discoverCover),
        name: analyzer
            .getString(rule.discoverName)
            .trim()
            .replaceAll(EsoApiConst.largeSpaceRegExp, EsoApiConst.fullSpace),
        author: analyzer.getString(rule.discoverAuthor),
        chapter: analyzer.getString(rule.discoverChapter),
        description: analyzer.getString(rule.discoverDescription),
        url: analyzer.getString(rule.discoverResult),
        origin: _origin,
        originTag: _originTag,
        ruleContentType: _ruleContentType,
        tags: tags,
      ));
    }
    return result;
  }

  @override
  Future<List<EsoSearchItem>> search(String query, int page, int pageSize) async {
    final hasNextUrlRule = rule.searchNextUrl.isNotEmpty;
    String? searchRule;
    var url = rule.searchUrl;
    final re = RegExp('url@.+@url', dotAll: true).stringMatch(query);
    if (re != null && re.isNotEmpty) {
      url = re.substring('url@'.length, re.length - '@url'.length);
      query = query.substring(re.length);
    }
    if (page == 1) {
      searchRule = url;
    } else if (hasNextUrlRule) {
      final next = _nextUrl?[url];
      if (next != null && next.isNotEmpty) {
        searchRule = next;
      }
    } else if (url.contains(EsoApiConst.pagePattern)) {
      searchRule = url;
    }
    if (searchRule == null) {
      return <EsoSearchItem>[];
    }

    var searchUrl = '';
    var body = '';
    if (rule.searchUrl != 'null') {
      final res = await EsoAnalyzeUrl.urlRuleParser(
        searchRule,
        rule,
        _client,
        page: page,
        pageSize: pageSize,
        keyword: query,
      );
      if (res.contentLength == 0) {
        return <EsoSearchItem>[];
      }
      searchUrl = res.request?.url.toString() ?? '';
      body = _decodeBody.decode(res.bodyBytes, res.headers['content-type']);
    }
    final bodyAnalyzer = _analyzer(body);
    if (hasNextUrlRule) {
      setNextUrl(url, bodyAnalyzer.getString(rule.searchNextUrl));
    }
    final list = bodyAnalyzer.getElements(rule.searchList);
    final result = <EsoSearchItem>[];
    for (final item in list) {
      final analyzer = _analyzer(item);
      final tag = analyzer.getString(rule.searchTags);
      var tags = <String>[];
      if (tag.trim().isNotEmpty) {
        tags = tag.split(EsoApiConst.tagsSplitRegExp)
          ..removeWhere((tag) => tag.isEmpty);
      }
      result.add(EsoSearchItem(
        searchUrl: searchUrl,
        cover: analyzer.getString(rule.searchCover),
        name: analyzer
            .getString(rule.searchName)
            .trim()
            .replaceAll(EsoApiConst.largeSpaceRegExp, EsoApiConst.fullSpace),
        author: analyzer.getString(rule.searchAuthor),
        chapter: analyzer.getString(rule.searchChapter),
        description: analyzer.getString(rule.searchDescription),
        url: analyzer.getString(rule.searchResult),
        origin: _origin,
        originTag: _originTag,
        ruleContentType: _ruleContentType,
        tags: tags,
      ));
    }
    return result;
  }

  /// 目录：`chapterUrl == "正文"` 时单章直出；给了 page 走增量翻页，否则循环拉全量。
  @override
  Future<List<EsoChapterItem>> chapter(String lastResult, [int? page]) async {
    if (rule.chapterUrl == '正文') {
      return <EsoChapterItem>[EsoChapterItem(url: lastResult, name: '正文')];
    }
    EsoApi.chapterUrl = null;
    if (page != null) {
      final result = <EsoChapterItem>[];
      if (page == 1) {
        chapterNextUrl = null;
      }
      try {
        final url = checkString(chapterNextUrl) ??
            checkString(rule.chapterUrl) ??
            lastResult;
        var chapterUrl = url;
        EsoApi.chapterUrl = chapterUrl;
        var body = '';
        if (url != 'null') {
          final res = await EsoAnalyzeUrl.urlRuleParser(
            url,
            rule,
            _client,
            result: lastResult,
            page: page,
          );
          if (res.contentLength == 0) {
            return result;
          }
          chapterUrl = res.request?.url.toString() ?? '';
          EsoApi.chapterUrl = chapterUrl;
          body = _decodeBody.decode(res.bodyBytes, res.headers['content-type']);
        }
        final bodyAnalyzer = _analyzer(body);
        if (rule.chapterNextUrl.isNotEmpty) {
          chapterNextUrl = bodyAnalyzer.getString(rule.chapterNextUrl);
        }
        if (rule.enableMultiRoads) {
          final roads = bodyAnalyzer.getElements(rule.chapterRoads);
          if (roads.isEmpty) {
            return result;
          }
          for (final road in roads) {
            final roadAnalyzer = _analyzer(road);
            result.add(EsoChapterItem(
              name: '@线路${roadAnalyzer.getString(rule.chapterRoadName)}',
            ));
            // 源实现把目录倒序开关在这条分支上暂时关闭，等价于直接用 chapterList
            final list = roadAnalyzer.getElements(rule.chapterList);
            if (list.isEmpty) {
              break;
            }
            for (final item in list) {
              result.add(_chapterItem(item));
            }
          }
        } else {
          final list = bodyAnalyzer.getElements(rule.chapterList);
          if (list.isEmpty) {
            return result;
          }
          for (final item in list) {
            result.add(_chapterItem(item));
          }
        }
      } catch (e) {
        // 源实现同样吞掉异常
      }
      return result;
    }
    final result = <EsoChapterItem>[];
    final reversed = rule.chapterList.startsWith('-');
    final hasNextUrlRule = rule.chapterNextUrl.isNotEmpty;
    final url =
        rule.chapterUrl.isNotEmpty ? rule.chapterUrl : lastResult;
    String? next;
    String? chapterUrlRule;
    for (var page = 1;; page++) {
      chapterUrlRule = null;
      if (page == 1) {
        chapterUrlRule = url;
      } else if (hasNextUrlRule) {
        if (next != null && next.isNotEmpty) {
          chapterUrlRule = next;
        }
      } else if (url.contains(EsoApiConst.pagePattern)) {
        chapterUrlRule = url;
      }
      if (chapterUrlRule == null) {
        break;
      }
      try {
        var chapterUrl = chapterUrlRule;
        EsoApi.chapterUrl = chapterUrl;
        var body = '';
        if (chapterUrlRule != 'null') {
          final res = await EsoAnalyzeUrl.urlRuleParser(
            chapterUrlRule,
            rule,
            _client,
            result: lastResult,
            page: page,
          );
          if (res.contentLength == 0) {
            break;
          }
          chapterUrl = res.request?.url.toString() ?? '';
          body = _decodeBody.decode(res.bodyBytes, res.headers['content-type']);
        }
        EsoApi.chapterUrl = chapterUrl;
        final bodyAnalyzer = _analyzer(body);
        if (hasNextUrlRule) {
          next = bodyAnalyzer.getString(rule.chapterNextUrl);
        } else {
          next = null;
        }
        if (rule.enableMultiRoads) {
          final roads = bodyAnalyzer.getElements(rule.chapterRoads);
          if (roads.isEmpty) {
            break;
          }
          for (final road in roads) {
            final roadAnalyzer = _analyzer(road);
            result.add(EsoChapterItem(
              name: '@线路${roadAnalyzer.getString(rule.chapterRoadName)}',
            ));
            final list = roadAnalyzer.getElements(
                reversed ? rule.chapterList.substring(1) : rule.chapterList);
            if (list.isEmpty) {
              break;
            }
            for (final item in (reversed ? list.reversed : list)) {
              result.add(_chapterItem(item));
            }
          }
        } else {
          final list = bodyAnalyzer.getElements(
              reversed ? rule.chapterList.substring(1) : rule.chapterList);
          if (list.isEmpty) {
            break;
          }
          for (final item in (reversed ? list.reversed : list)) {
            result.add(_chapterItem(item));
          }
        }
      } catch (e) {
        break;
      }
    }
    return result;
  }

  /// 单个目录项：锁定标记 `🔒` + 名称空白压缩。
  EsoChapterItem _chapterItem(dynamic item) {
    final analyzer = _analyzer(item);
    final lock = analyzer.getString(rule.chapterLock);
    var name = analyzer
        .getString(rule.chapterName)
        .trim()
        .replaceAll(EsoApiConst.largeSpaceRegExp, EsoApiConst.fullSpace);
    if (lock.isNotEmpty &&
        lock != 'undefined' &&
        lock != 'false' &&
        lock != '0') {
      name = '🔒$name';
    }
    return EsoChapterItem(
      cover: analyzer.getString(rule.chapterCover),
      name: name,
      time: analyzer.getString(rule.chapterTime),
      url: analyzer.getString(rule.chapterResult),
    );
  }

  @override
  Future<List<String>> content(String lastResult) async {
    EsoApi.contentUrl = null;
    final result = <String>[];
    final hasNextUrlRule = rule.contentNextUrl.isNotEmpty;
    final url = rule.contentUrl.isNotEmpty ? rule.contentUrl : lastResult;
    String? next;
    String? contentUrlRule;
    for (var page = 1;; page++) {
      contentUrlRule = null;
      if (page == 1) {
        contentUrlRule = url;
      } else if (hasNextUrlRule) {
        if (next != null && next.isNotEmpty) {
          contentUrlRule = next;
        }
      } else if (url.contains(EsoApiConst.pagePattern)) {
        contentUrlRule = url;
      }
      if (contentUrlRule == null) {
        return result;
      }
      try {
        var contentUrl = '';
        var body = '';
        if (contentUrlRule != 'null') {
          final res = await EsoAnalyzeUrl.urlRuleParser(
            contentUrlRule,
            rule,
            _client,
            result: lastResult,
            page: page,
          );
          if (res.contentLength == 0) {
            break;
          }
          contentUrl = res.request?.url.toString() ?? '';
          body = _decodeBody.decode(res.bodyBytes, res.headers['content-type']);
        }
        EsoApi.contentUrl = contentUrl;
        final bodyAnalyzer = _analyzer(body);
        if (hasNextUrlRule) {
          next = bodyAnalyzer.getString(rule.contentNextUrl);
        } else {
          next = null;
        }
        final list = bodyAnalyzer.getStringList(rule.contentItems);
        if (list.isEmpty || list.join().trim().isEmpty) {
          break;
        }
        result.addAll(list);
      } catch (e) {
        /// 内容为空抛出错误（源实现会 toast「解析失败」）
        if (result.isEmpty) {
          switch (_ruleContentType) {
            case EsoApi.video:
            case EsoApi.novel:
              rethrow;
            case EsoApi.audio:
            case EsoApi.manga:
              break;
            default:
          }
        }
        break;
      }
    }
    return result;
  }

  @override
  Future<List<EsoDiscoverMap>> discoverMap() async {
    final map = <EsoDiscoverMap>[];
    final table = <String, int>{};
    dynamic discoverUrl = rule.discoverUrl.trimLeft();
    try {
      if (discoverUrl is String && discoverUrl.startsWith('@js:')) {
        throw EsoRuleException('宿主未移植 @js: 规则引擎');
      }
      final Iterable<String> discovers = (discoverUrl is List)
          ? discoverUrl.map((e) => '$e')
          : (discoverUrl is String)
              ? discoverUrl.split(RegExp(r'\n\s*|&&'))
              : <String>[];
      for (final url in discovers) {
        if (url.trim().isEmpty) continue;
        final d = url.split('::');
        final ruleUrl = d.last.trim();
        String? tab;
        String? className;
        if (d.length == 1) {
          tab = '全部';
          className = '全部';
        } else if (d.length == 2) {
          tab = d[0].trim();
          className = '全部';
        } else if (d.length == 3) {
          tab = d[0].trim();
          className = d[1].trim();
        }
        if (tab == null || className == null) continue;
        if (table[tab] == null) {
          table[tab] = map.length;
          map.add(EsoDiscoverMap(tab, <EsoDiscoverPair>[
            EsoDiscoverPair(className, ruleUrl),
          ]));
        } else {
          map[table[tab]!].pairs.add(EsoDiscoverPair(className, ruleUrl));
        }
      }
    } catch (e) {
      // 源实现同样吞掉异常并回落到默认分类
    }
    if (map.isEmpty) {
      if (rule.host.startsWith('http')) {
        map.add(EsoDiscoverMap('全部', <EsoDiscoverPair>[
          EsoDiscoverPair('全部', rule.host),
        ]));
      } else {
        map.add(EsoDiscoverMap('example', <EsoDiscoverPair>[
          EsoDiscoverPair('example', 'http://example.com/'),
        ]));
      }
    }
    return map;
  }
}
