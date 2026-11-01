import 'package:dashboard/features/shared/ui/content_entry_section.dart';
import 'package:dashboard/features/anime/anime_module_page.dart';
import 'package:dashboard/features/chat/chat_module_page.dart';
import 'package:dashboard/features/comic/comic_module_page.dart';
import 'package:dashboard/features/crawler/crawler_module_page.dart';
import 'package:dashboard/features/live/live_module_page.dart';
import 'package:dashboard/features/movie/movie_module_page.dart';
import 'package:dashboard/features/novel/novel_module_page.dart';
import 'package:dashboard/features/reading/reading_module_page.dart';
import 'package:dashboard/features/shared/ui/content_entry.dart';
import 'package:dashboard/features/shared/ui/content_tokens.dart';
import 'package:dashboard/features/source_library/source_library_page.dart';
import 'package:flutter/material.dart';

/// Single source of truth for the top-level content modules.
///
/// The hub renders this catalog; each entry opens the module page that owns
/// that business area, so the hub no longer keeps its own copy of titles,
/// descriptions and icons.
final List<ContentEntrySection> contentModuleCatalog = [
  ContentEntrySection(
    title: '内容模块',
    description: '一个入口访问阅读、影音、社区与直播内容',
    entries: [
      ContentEntry(
        id: 'reading',
        title: '阅读',
        subtitle: '书架、章节阅读与阅读偏好设置',
        icon: Icons.chrome_reader_mode_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const ReadingModulePage(),
      ),
      ContentEntry(
        id: 'novel',
        title: '小说',
        subtitle: '分类、排行、更新与轻小说详情',
        icon: Icons.auto_stories_outlined,
        accent: ContentAccents.novel,
        builder: (_) => const NovelModulePage(),
      ),
      ContentEntry(
        id: 'anime',
        title: '动漫',
        subtitle: '最近更新、目录、搜索和收藏入口',
        icon: Icons.animation_outlined,
        accent: ContentAccents.anime,
        builder: (_) => const AnimeModulePage(),
      ),
      ContentEntry(
        id: 'comic',
        title: '漫画',
        subtitle: '推荐、分类、排行、下载与阅读进度',
        icon: Icons.menu_book_outlined,
        accent: ContentAccents.comic,
        builder: (_) => const ComicModulePage(),
      ),
      ContentEntry(
        id: 'movie',
        title: '影视',
        subtitle: '首页推荐、分类、搜索、详情和播放清单',
        icon: Icons.movie_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const MovieModulePage(),
      ),
      ContentEntry(
        id: 'chat',
        title: '聊天',
        subtitle: '本地会话、局域网聊天与消息记录',
        icon: Icons.forum_outlined,
        accent: ContentAccents.chat,
        builder: (_) => const ChatModulePage(),
      ),
      ContentEntry(
        id: 'live',
        title: '直播',
        subtitle: '频道订阅、多线路播放和在线直播间',
        icon: Icons.live_tv_outlined,
        accent: ContentAccents.live,
        builder: (_) => const LiveModulePage(),
      ),
      ContentEntry(
        id: 'crawler',
        title: '爬虫',
        subtitle: '网页链接采集、任务控制、日志和配置导出',
        icon: Icons.travel_explore,
        accent: ContentAccents.crawler,
        builder: (_) => const CrawlerModulePage(),
      ),
    ],
  ),
  ContentEntrySection(
    title: '统一内容源',
    description: '集中查找已接入的动漫、小说、视频、漫画、直播、媒体与采集逻辑',
    entries: [
      ContentEntry(
        id: 'source-library',
        title: '内容源库',
        subtitle: '按内容类型浏览统一接入的来源与播放器',
        icon: Icons.hub_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const SourceLibraryPage(),
      ),
    ],
  ),
];
