import 'package:dashboard/app/platform/app_capability.dart';
import 'package:dashboard/features/shared/ui/content_entry_section.dart';
import 'package:dashboard/features/anime/animeone/animeone_module_page.dart';
import 'package:dashboard/features/anime/kazumi_entry.dart';
import 'package:dashboard/features/anime/animetrace/animetrace_page.dart';
import 'package:dashboard/features/anime/takoplay/tako_play_search_page.dart';
import 'package:dashboard/features/anime/tsdm/tsdm_api_urls.dart';
import 'package:dashboard/features/anime/tsdm/tsdm_latest_thread_page.dart';
import 'package:dashboard/features/shared/ui/content_entry.dart';
import 'package:dashboard/features/shared/ui/content_tokens.dart';
import 'package:flutter/material.dart';

/// Anime sites. Recently-updated, catalogue, search and favourites stay on the
/// module page; this catalog only lists the external sources.
final List<ContentEntrySection> animeEntryCatalog = [
  ContentEntrySection(
    title: '动漫站点',
    description: '在线番剧、论坛与以图搜番',
    entries: [
      ContentEntry(
        id: 'kazumi-webdav',
        title: 'Kazumi · 规则番剧与 WebDAV',
        subtitle: 'XPath 源、番剧收藏、WebDAV 同步、字幕与 DLNA',
        icon: Icons.video_library_outlined,
        accent: ContentAccents.anime,
        tooltip: 'Kazumi WebDAV',
        builder: (_) => const KazumiEmbeddedPage(),
      ),
      ContentEntry(
        id: 'animeone',
        title: 'AnimeOne 番剧',
        subtitle: 'anime1 线路 · 最近更新 / 目录 / 详情',
        icon: Icons.ondemand_video_outlined,
        accent: ContentAccents.anime,
        tooltip: 'anime1 · AnimeOne',
        builder: (_) => const AnimeOneModulePage(),
      ),
      ContentEntry(
        id: 'takoplay',
        title: 'TakoPlay 搜索',
        subtitle: 'gogoanime 搜索 · 详情与播放线路',
        icon: Icons.live_tv_outlined,
        accent: ContentAccents.anime,
        tooltip: 'TakoPlay · gogoanime',
        builder: (_) => const TakoPlaySearchPage(),
      ),
      ContentEntry(
        id: 'tsdm',
        title: '天使动漫 · 最新帖子',
        subtitle: 'TSDM 论坛最新主题与回复',
        icon: Icons.forum_outlined,
        accent: ContentAccents.anime,
        tooltip: '天使动漫 · TSDM 论坛',
        builder: (_) => const TsdmLatestThreadPage(
          url: TsdmApiUrls.homePage,
          title: '天使动漫 · 最新帖子',
        ),
      ),
      ContentEntry(
        id: 'animetrace',
        requires: AppCapability.fileSystem,
        title: '漫迹 AnimeTrace',
        subtitle: '以图搜番 · 相似度与番剧信息',
        icon: Icons.collections_bookmark_outlined,
        accent: ContentAccents.anime,
        tooltip: '漫迹 AnimeTrace',
        builder: (_) => const AnimeTracePage(),
      ),
    ],
  ),
];
