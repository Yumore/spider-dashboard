import 'package:dashboard/app/platform/app_capability.dart';
import 'package:dashboard/features/anime/anime_entry_catalog.dart';
import 'package:dashboard/features/comic/comic_entry_catalog.dart';
import 'package:dashboard/features/crawler/crawler_module_page.dart';
import 'package:dashboard/features/live/live_entry_catalog.dart';
import 'package:dashboard/features/media/media_source_input_page.dart';
import 'package:dashboard/features/movie/movie_entry_catalog.dart';
import 'package:dashboard/features/novel/novel_entry_catalog.dart';
import 'package:dashboard/features/shared/ui/content_entry.dart';
import 'package:dashboard/features/shared/ui/content_entry_section.dart';
import 'package:dashboard/features/shared/ui/content_tokens.dart';
import 'package:dashboard/features/short_drama/short_drama_module_page_export.dart';
import 'package:flutter/material.dart';

/// Unified categories that route to the already-integrated business modules.
final List<({String title, List<ContentEntrySection> sections})>
sourceLibraryCategories = [
  (title: '动漫', sections: animeEntryCatalog),
  (title: '小说', sections: novelEntryCatalog),
  (title: '视频', sections: movieEntryCatalog),
  (
    title: '短剧',
    sections: [
      ContentEntrySection(
        title: '真果鉴 · 全站源',
        description: '短剧目录、追剧记录、下载离线与局域网同步',
        entries: [
          ContentEntry(
            id: 'hongguo-short-drama-library',
            requires: AppCapability.shortDrama,
            title: '短剧工作台',
            subtitle: '站源浏览、播放、下载管理与多用户权限',
            icon: Icons.live_tv_outlined,
            accent: ContentAccents.movie,
            builder: (_) => const ShortDramaModulePage(),
          ),
        ],
      ),
    ],
  ),
  (title: '漫画', sections: comicEntryCatalog),
  (title: '直播', sections: liveEntryCatalog),
  (
    title: '媒体',
    sections: [
      ContentEntrySection(
        title: '媒体播放',
        description: '使用宿主播放器播放可访问的 HTTP(S) 直连媒体',
        entries: [
          ContentEntry(
            id: 'media-direct-playback',
            requires: AppCapability.videoPlayback,
            title: '媒体直连播放',
            subtitle: 'MP4 / M3U8 / DASH 等媒体地址',
            icon: Icons.play_circle_outline,
            accent: ContentAccents.movie,
            builder: (_) => const MediaSourceInputPage(),
          ),
        ],
      ),
    ],
  ),
  (
    title: '采集',
    sections: [
      ContentEntrySection(
        title: '网页采集',
        description: '任务控制、公开网页解析、日志与配置导出',
        entries: [
          ContentEntry(
            id: 'crawler-workbench',
            title: '网页采集工作台',
            subtitle: '管理采集任务并查看解析结果',
            icon: Icons.travel_explore,
            accent: ContentAccents.crawler,
            builder: (_) => const CrawlerModulePage(),
          ),
        ],
      ),
    ],
  ),
];
