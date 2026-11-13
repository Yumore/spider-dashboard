import 'dart:collection';

import 'package:dashboard/features/comic/picacomic/core/account_config.dart';
import 'package:dashboard/features/comic/picacomic/core/base_comic.dart';
import 'package:dashboard/features/comic/picacomic/core/category_comics_data.dart';
import 'package:dashboard/features/comic/picacomic/core/category_comics_options.dart';
import 'package:dashboard/features/comic/picacomic/core/category_data.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_info_data.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_source.dart';
import 'package:dashboard/features/comic/picacomic/core/comment.dart';
import 'package:dashboard/features/comic/picacomic/core/explore_page_data.dart';
import 'package:dashboard/features/comic/picacomic/core/explore_page_part.dart';
import 'package:dashboard/features/comic/picacomic/core/explore_page_type.dart';
import 'package:dashboard/features/comic/picacomic/core/favorite_data.dart';
import 'package:dashboard/features/comic/picacomic/core/fixed_category_part.dart';
import 'package:dashboard/features/comic/picacomic/core/random_category_part_with_runtime_data.dart';
import 'package:dashboard/features/comic/picacomic/core/res.dart';
import 'package:dashboard/features/comic/picacomic/core/search_options.dart';
import 'package:dashboard/features/comic/picacomic/core/search_page_data.dart';
import 'package:dashboard/features/comic/picacomic/network/nhentai_models.dart';
import 'package:dashboard/features/comic/picacomic/network/nhentai_network.dart';
import 'package:dashboard/features/comic/picacomic/network/nhentai_tags.dart';
import 'package:dashboard/features/comic/picacomic/network/web_user_agent.dart';

/// Ports the `nhentai` built-in source
/// (PicaComic lib/comic_source/built_in/nhentai.dart).
///
/// Deviations:
/// * the `推荐` category button and `onLogin` webview flow are not ported: the
///   host has no navigation hooks in the source layer and no login page in
///   this write scope (webview_flutter is available but out of scope);
/// * the global `appdata.settings[69]` preference is not ported; the host
///   exposes equivalent language choices directly in search and tag results;
/// * `comicTileBuilderOverride` / `comicPageBuilder` are dropped, so
///   `enableTagsTranslation` travels on the model instead.
final ComicSource nhentaiSource = ComicSource(
  name: 'nhentai',
  key: 'nhentai',
  filePath: 'built-in',
  matchBriefIdReg: r'^(\d+|nh\d+|nhentai\d+)$',
  favoriteData: FavoriteData(
    key: 'nhentai',
    title: 'nhentai',
    multiFolder: false,
    loadComic: (i, [folder]) => _network().getFavorites(i),
  ),
  categoryData: CategoryData(
    title: 'nhentai',
    key: 'nhentai',
    enableRankingPage: false,
    categories: [
      const FixedCategoryPart(
        'language',
        ['中文', '日本語', 'english'],
        'category',
        ['/language/chinese', '/language/japanese', '/language/english'],
      ),
      RandomCategoryPartWithRuntimeData(
        'Tags',
        () => nhentaiTags.values.toList(),
        50,
        'search',
      ),
    ],
  ),
  categoryComicsData: CategoryComicsData(
    load: (category, param, options, page) async {
      final parts = (param ?? '').split('/');
      if (parts.length < 3) {
        return Res<List<BaseComic>>.error('invalid category param: $param');
      }
      final type = parts[1];
      final name = parts[2];
      final sort = NhentaiSort.fromValue(options.isEmpty ? '' : options[0]);
      final language = options.length > 1 ? options[1] : '';
      if (language.isNotEmpty) {
        return _network().search('$type:$name $language', page, sort);
      }
      return _network().getCategoryComics('/$type/$name', page, sort);
    },
    options: [
      CategoryComicsOptions(
        options: LinkedHashMap.of({
          '': '最近',
          '&sort=popular-today': '热门 | 今天',
          '&sort=popular-week': '热门 | 一周',
          '&sort=popular-month': '热门 | 本月',
          '&sort=popular': '热门 | 所有时间',
        }),
        notShowWhen: const ['random', 'latest'],
      ),
      CategoryComicsOptions(
        options: LinkedHashMap.of({
          '': '语言：全部',
          'language:chinese': '语言：中文',
          'language:english': '语言：English',
          'language:japanese': '语言：日本語',
        }),
        notShowWhen: const ['random', 'latest', '中文', '日本語', 'english'],
      ),
    ],
  ),
  account: AccountConfig(
    logout: () {
      nhentaiSource.data.remove('account');
      _network().logged = false;
      nhentaiSource.saveData();
    },
    allowReLogin: false,
  ),
  explorePages: [
    ExplorePageData(
      title: 'nhentai',
      type: ExplorePageType.mixed,
      loadMixed: (index) async {
        final res = await _network().getHomePage(index);
        if (res.error) return Res.fromErrorRes(res);
        if (index == 1) {
          return Res(<Object>[
            ExplorePagePart('Popular', res.data.popular, null),
            res.data.latest,
          ], subData: 20000);
        }
        return Res(<Object>[res.data.latest], subData: 20000);
      },
    ),
  ],
  searchPageData: SearchPageData(
    enableLanguageFilter: true,
    enableTagsSuggestions: true,
    loadPage: (keyword, page, options) => _network().search(
      keyword,
      page,
      NhentaiSort.fromValue(options.isEmpty ? '' : options[0]),
    ),
    searchOptions: [
      SearchOptions(
        LinkedHashMap.of({
          '': '最近',
          '&sort=popular-today': '热门 | 今天',
          '&sort=popular-week': '热门 | 一周',
          '&sort=popular-month': '热门 | 本月',
          '&sort=popular': '热门 | 所有时间',
        }),
        '排序',
      ),
    ],
  ),
  loadComicInfo: (id) async {
    final res = await _network().getComicInfo(id);
    if (res.error) return Res.fromErrorRes(res);
    final comic = res.data;
    return Res(
      ComicInfoData(
        comic.title,
        comic.subTitle,
        comic.cover,
        comic.tags['时间']?.first ?? '',
        comic.tags,
        {'1': '全部'},
        comic.thumbnails.isEmpty ? null : comic.thumbnails,
        (id, page) async {
          final images = await _network().getImages(id);
          if (images.error) return Res.fromErrorRes(images);
          final start = (page - 1) * 20;
          final end = (start + 20).clamp(0, images.data.length);
          return Res(
            start >= images.data.length
                ? <String>[]
                : images.data.sublist(start, end),
          );
        },
        (comic.thumbnails.length / 20).ceil().clamp(1, 1000),
        comic.recommendations,
        'nhentai',
        comic.id,
        isFavorite: comic.favorite,
      ),
    );
  },
  loadComicPages: (id, ep) => _network().getImages(id),
  commentsLoader: (id, subId, page, replyTo) async {
    if (page > 1) return const Res([]);
    final res = await _network().getComments(id);
    if (res.error) return Res.fromErrorRes(res);
    return Res([
      for (var i = 0; i < res.data.length; i++)
        Comment(
          res.data[i].userName,
          res.data[i].avatar,
          res.data[i].content,
          DateTime.fromMillisecondsSinceEpoch(
            res.data[i].date * 1000,
          ).toIso8601String(),
          0,
          '$i',
        ),
    ]);
  },
  getImageLoadingConfig: (imageKey, comicId, epId) => {
    'headers': {'User-Agent': webUserAgent},
  },
  getThumbnailLoadingConfig: (imageKey) => {
    'headers': {'User-Agent': webUserAgent},
  },
);

NhentaiNetwork? _cachedNhentaiNetwork;

/// Test seam: replaces the client used by every nhentai request.
void setNhentaiNetworkForTest(NhentaiNetwork? network) {
  _cachedNhentaiNetwork = network;
}

NhentaiNetwork _network() =>
    _cachedNhentaiNetwork ??= NhentaiNetwork(logged: _logged);

/// Mirrors `NhentaiNetwork().logged`, which the source read straight off the
/// singleton (nhentai.dart:85).
bool _logged = false;

/// Lets the host restore the persisted session flag without touching Dio.
set nhentaiLogged(bool value) => _logged = value;

bool get nhentaiLoggedValue => _logged;

/// Helper used by tests and the source layer: raw gallery `categoryType`.
List<BaseComic> asBaseComics(List<NhentaiComicBrief> briefs) =>
    briefs.cast<BaseComic>();
