import 'package:dashboard/features/comic/picacomic/core/account_config.dart';
import 'package:dashboard/features/comic/picacomic/core/account_info_item.dart';
import 'package:dashboard/features/comic/picacomic/core/category_comics_data.dart';
import 'package:dashboard/features/comic/picacomic/core/category_data.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_info_data.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_source.dart';
import 'package:dashboard/features/comic/picacomic/core/comment.dart';
import 'package:dashboard/features/comic/picacomic/core/explore_page_data.dart';
import 'package:dashboard/features/comic/picacomic/core/explore_page_type.dart';
import 'package:dashboard/features/comic/picacomic/core/favorite_data.dart';
import 'package:dashboard/features/comic/picacomic/core/picacomic_tag_translator.dart';
import 'package:dashboard/features/comic/picacomic/core/random_category_part_with_runtime_data.dart';
import 'package:dashboard/features/comic/picacomic/core/ranking_data.dart';
import 'package:dashboard/features/comic/picacomic/core/res.dart';
import 'package:dashboard/features/comic/picacomic/core/search_page_data.dart';
import 'package:dashboard/features/comic/picacomic/network/eh_models.dart';
import 'package:dashboard/features/comic/picacomic/network/eh_network.dart';
import 'package:dashboard/features/comic/picacomic/network/web_user_agent.dart';
import 'package:dashboard/features/comic/picacomic/sources/eh_galleries_pager.dart';
import 'package:dashboard/features/comic/picacomic/sources/ehentai_requests.dart';
import 'package:dashboard/features/comic/picacomic/sources/ehentai_tags.dart';

/// Ports the `ehentai` built-in source
/// (PicaComic lib/comic_source/built_in/ehentai.dart).
///
/// Not ported: the Flutter tile/page builders (`comicTileBuilderOverride`,
/// `comicPageBuilder`) because the host module renders comics through its own
/// pages, and the `onLogin` web-view cookie flow (the host has no webview-based
/// e-hentai login screen); cookies can still be written to `data['cookies']`.
final ComicSource ehentaiSource = ComicSource(
  name: 'ehentai',
  key: 'ehentai',
  filePath: 'built-in',
  favoriteData: FavoriteData(
    key: 'ehentai',
    title: 'ehentai',
    multiFolder: true,
    loadComic: (page, [folderId]) =>
        _favoritePager(folderId ?? '-1').load(page),
    loadFolders: ([comicId]) async {
      final res = await _network().getGalleries(
        EhentaiRequests.favoritesUrl('-1'),
        favoritePage: true,
      );
      if (res.error) return Res.fromErrorRes(res);
      final network = _network();
      final folders = <String>['全部', ...network.folderNames];
      final result = <String, String>{};
      for (var i = -1; i < network.folderNames.length; i++) {
        result['$i'] = folders[i + 1];
      }
      return Res(result);
    },
    addOrDeleteFavorite: (comicId, folderId, isAdding) async {
      final network = _network();
      final info = await network.getGalleryInfo(comicId);
      if (info.error) return Res.fromErrorRes(info);
      final auth = info.data.auth ?? const <String, String>{};
      final gid = auth['gid'] ?? getGalleryId(comicId);
      final token = auth['token'] ?? '';
      final ok = isAdding
          ? await network.favorite(gid, token, id: folderId)
          : await network.unfavorite(gid, token);
      return Res(ok);
    },
  ),
  categoryData: CategoryData(
    title: 'ehentai',
    key: 'ehentai',
    enableRankingPage: true,
    categories: [
      for (final title in ehentaiCategoryPartTitles)
        RandomCategoryPartWithRuntimeData(
          title,
          () => PicacomicTagTranslator.tagsForNamespace(
            title,
            fallback: ehentaiNamespaceTags[title] ?? const <String>[],
          ),
          20,
          title == 'character' ? 'search' : 'search_with_namespace',
        ),
    ],
  ),
  categoryComicsData: CategoryComicsData(
    load: (category, param, options, page) =>
        _searchPagerFor(param ?? category).load(page),
    rankingData: RankingData(
      options: const {'15': '昨天', '13': '本月', '12': '今年', '11': '全部'},
      load: (option, page) {
        final type = int.tryParse(option) ?? 15;
        return _network().getLeaderBoardByPage(type, page);
      },
    ),
  ),
  account: AccountConfig(
    allowReLogin: false,
    logout: () {
      ehentaiSource.data
        ..remove('cookies')
        ..remove('name');
      ehentaiSource.saveData();
    },
    infoItems: [
      AccountInfoItem(
        title: '用户名',
        data: () => ehentaiSource.data['name'] as String? ?? '',
      ),
    ],
  ),
  explorePages: [
    ExplorePageData(
      title: 'Eh主页',
      type: ExplorePageType.multiPageComicList,
      loadPage: _explorePager(EhentaiRequests.homePath).load,
    ),
    ExplorePageData(
      title: 'Eh热门',
      type: ExplorePageType.multiPageComicList,
      loadPage: _explorePager(EhentaiRequests.popularPath).load,
    ),
  ],
  searchPageData: SearchPageData(
    enableLanguageFilter: true,
    enableTagsSuggestions: true,
    loadPage: (keyword, page, options) {
      final pager = _searchPagers.putIfAbsent(
        'search:$keyword',
        () => _newPager(() async {
          final res = await _network().search(
            keyword,
            fCats: _intAt(options, 0),
            startPages: _intAt(options, 1),
            endPages: _intAt(options, 2),
            minStars: _intAt(options, 3),
          );
          return res;
        }),
      );
      return pager.load(page);
    },
  ),
  loadComicInfo: (id) async {
    final network = _network();
    final res = await network.getGalleryInfo(id);
    if (res.error) return Res.fromErrorRes(res);
    final gallery = res.data;
    final readerPages = gallery.maxPage <= 0
        ? 1
        : (gallery.maxPage / 20).ceil();
    final thumbnailKey = gallery.auth?['thumbnailKey'];
    final largeThumbnailPages = thumbnailKey == null
        ? null
        : int.tryParse(RegExp(r'\d+').firstMatch(thumbnailKey)?.group(0) ?? '');
    return Res(
      ComicInfoData(
        gallery.title,
        gallery.subTitle,
        gallery.coverPath,
        '${gallery.type}    ${gallery.time}',
        gallery.tags,
        {for (var i = 1; i <= readerPages; i++) '$i': '第 $i 页'},
        gallery.thumbnails.isEmpty ? null : gallery.thumbnails,
        largeThumbnailPages == null
            ? null
            : (id, page) => network.getLargeThumbnails(gallery, page),
        largeThumbnailPages ?? 1,
        null,
        'ehentai',
        gallery.link,
        isFavorite: gallery.favorite,
      ),
    );
  },
  loadComicPages: (id, ep) async {
    final network = _network();
    final page = int.tryParse(ep ?? '1') ?? 1;
    final links = await network.getReaderLinks(id, page);
    if (links.error) return Res.fromErrorRes(links);
    final images = <String>[];
    for (final link in links.data) {
      final image = await network.getImageUrl(link);
      if (image.error) return Res.fromErrorRes(image);
      images.add(image.data);
    }
    return Res(images);
  },
  getImageLoadingConfig: (imageKey, comicId, epId) => {
    'headers': _network().requestHeaders,
  },
  getThumbnailLoadingConfig: (imageKey) => {
    'headers': {
      'User-Agent': webUserAgent,
      'Referer': _network().baseUrl,
      'Cookie': _network().cookiesStr,
    },
  },
  commentsLoader: (id, subId, page, replyTo) async {
    if (page > 1) return const Res(<Comment>[]);
    final res = await _network().getComments(id);
    if (res.error) return Res.fromErrorRes(res);
    return Res(
      res.data
          .map((e) => Comment(e.name, '', e.content, e.time, 0, e.id))
          .toList(),
    );
  },
  sendCommentFunc: (id, subId, content, replyTo) =>
      _network().comment(content, id),
);

final Map<String, EhGalleriesPager> _searchPagers = {};
final Map<String, EhGalleriesPager> _favoritePagers = {};
final Map<String, EhGalleriesPager> _explorePagers = {};

EhNetwork? _cachedNetwork;

/// Test seam: replaces the [Dio] used by every e-hentai request.
void setEhentaiNetworkForTest(EhNetwork? network) {
  _cachedNetwork = network;
  _searchPagers.clear();
  _favoritePagers.clear();
  _explorePagers.clear();
}

EhNetwork _network() => _cachedNetwork ??= EhNetwork(
  cookieProvider: () => ehentaiSource.data['cookies'] as String? ?? '',
  exhentai: ehentaiSource.data['exhentai'] == true,
  onFolderNames: (folders) {
    ehentaiSource.data['favoriteNames'] = folders;
    ehentaiSource.saveData();
  },
);

EhGalleriesPager _newPager(Future<Res<EhGalleries>> Function() firstPage) =>
    EhGalleriesPager(
      firstPageLoader: firstPage,
      nextPageLoader: (url) => _network().getGalleries(url),
    );

EhGalleriesPager _explorePager(String path) => _explorePagers.putIfAbsent(
  path,
  () => _newPager(() => _network().getGalleries('${_network().baseUrl}$path')),
);

EhGalleriesPager _favoritePager(String folderId) => _favoritePagers.putIfAbsent(
  folderId,
  () => _newPager(
    () => _network().getGalleries(
      EhentaiRequests.favoritesUrl(folderId),
      favoritePage: true,
    ),
  ),
);

EhGalleriesPager _searchPagerFor(String keyword) => _searchPagers.putIfAbsent(
  'category:$keyword',
  () => _newPager(() => _network().search(keyword)),
);

int? _intAt(List<String> values, int index) {
  if (index >= values.length) return null;
  return int.tryParse(values[index]);
}

/// Exposed for the category page: the search expression used for a clicked tag.
String ehentaiCategoryKeyword(String category, String? param) =>
    param ?? category;

/// Exposed for the module/tests: clears every cached listing page.
void resetEhentaiPagers() {
  _searchPagers.clear();
  _favoritePagers.clear();
  _explorePagers.clear();
}
