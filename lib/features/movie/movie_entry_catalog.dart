import 'package:dashboard/app/platform/app_capability.dart';
import 'package:dashboard/features/shared/ui/content_entry_section.dart';
import 'package:dashboard/features/movie/bilivideo_down/bili_video_down_page.dart';
import 'package:dashboard/features/movie/dytt/dytt_page.dart';
import 'package:dashboard/features/movie/eyepetizer/eyepetizer_home_page.dart';
import 'package:dashboard/features/movie/eyepetizer_flutter/eyepetizer_flutter_home_page.dart';
import 'package:dashboard/features/movie/fluttercinematic/pages/cinematic_home_page.dart';
import 'package:dashboard/features/movie/flutterdouban/flutterdouban_page.dart';
import 'package:dashboard/features/movie/fluttermovies/fluttermovies_page.dart';
import 'package:dashboard/features/movie/inkino/inkino_page.dart';
import 'package:dashboard/features/movie/movieapp/movieapp_page.dart';
import 'package:dashboard/features/movie/tvbox/tvbox_catalog_page.dart';
import 'package:dashboard/features/media/local_media_library_page.dart';
import 'package:dashboard/features/movie/youtubedl/youtubedl_page.dart';
import 'package:dashboard/features/movie/yyets/yyets_home_page.dart';
import 'package:dashboard/features/shared/ui/content_entry.dart';
import 'package:dashboard/features/shared/ui/content_tokens.dart';
import 'package:dashboard/features/short_video/douyin/douyin_entry_page.dart';
import 'package:dashboard/features/short_video/short_video_demo_page.dart';
import 'package:dashboard/features/short_drama/short_drama_module_page_export.dart';
import 'package:flutter/material.dart';

/// Movie and short-video services reachable from the movie module.
///
/// Backend-driven discovery and the local watch list stay on the page; this
/// catalog lists the external video sources and the local short-video demos.
final List<ContentEntrySection> movieEntryCatalog = [
  ContentEntrySection(
    title: '影视服务与短视频',
    description: '在线影视站点、短剧、短视频演示与下载工具',
    entries: [
      ContentEntry(
        id: 'eyepetizer',
        title: '开眼 · Eyepetizer',
        subtitle: '精选短视频每日推荐',
        icon: Icons.remove_red_eye_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const EyepetizerHomePage(),
      ),
      ContentEntry(
        id: 'eyepetizer-flutter',
        title: '开眼社区 · 登录/个人/图片',
        subtitle: '账号登录、个人主页与图片浏览',
        icon: Icons.account_circle_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const EyepetizerFlutterHomePage(),
      ),
      ContentEntry(
        id: 'bilibili-download',
        requires: AppCapability.fileSystem,
        title: 'B站视频下载',
        subtitle: '视频解析、清晰度选择与本地下载',
        icon: Icons.download_for_offline_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const BiliVideoDownPage(),
      ),
      ContentEntry(
        id: 'fluttermovies',
        title: '今日看片 · FlutterMovies',
        subtitle: '热门电影推荐与详情',
        icon: Icons.local_play_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const FlutterMoviesPage(),
      ),
      ContentEntry(
        id: 'flutterdouban',
        title: '豆瓣电影 · FlutterDouBan',
        subtitle: '豆瓣榜单、详情与影评',
        icon: Icons.local_movies_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const FlutterDouBanPage(),
      ),
      ContentEntry(
        id: 'movieapp',
        title: 'MovieApp · TMDb',
        subtitle: '热门电影、搜索与详情',
        icon: Icons.movie_filter_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const MovieAppPage(),
      ),
      ContentEntry(
        id: 'cinematic',
        title: 'FlutterCinematic · TMDb',
        subtitle: '影片详情与演员信息',
        icon: Icons.local_movies_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const CinematicHomePage(),
      ),
      ContentEntry(
        id: 'inkino',
        title: 'inKino · Finnkino 场次',
        subtitle: '芬兰影院排片与预告',
        icon: Icons.theaters_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const InKinoPage(),
      ),
      ContentEntry(
        id: 'yyets',
        title: '人人影视 · YYeTs',
        subtitle: '字幕组资源搜索与下载',
        icon: Icons.subtitles_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const YyetsHomePage(),
      ),
      ContentEntry(
        id: 'hongguo-short-drama',
        requires: AppCapability.shortDrama,
        title: '真果鉴 · 全站源短剧',
        subtitle: '浏览搜索、多站源播放、追剧、下载、离线与局域网续播',
        icon: Icons.live_tv_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const ShortDramaModulePage(),
      ),
      ContentEntry(
        id: 'short-video-demo',
        requires: AppCapability.videoPlayback,
        title: '本地短视频演示',
        subtitle: '双击点赞、关注/推荐布局与竖向视频列表',
        icon: Icons.video_library_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const ShortVideoDemoPage(),
      ),
      ContentEntry(
        id: 'douyin',
        requires: AppCapability.videoPlayback,
        title: '抖音短视频',
        subtitle: '本地实现的抖音首页、评论与个人页',
        icon: Icons.music_note_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const DouyinEntryPage(),
      ),
      ContentEntry(
        id: 'youtube-download',
        requires: AppCapability.fileSystem,
        title: 'YouTube 下载',
        subtitle: '视频信息解析与下载',
        icon: Icons.download_for_offline_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const YoutubeDlPage(),
      ),
      ContentEntry(
        id: 'dytt',
        title: '电影天堂',
        subtitle: '最新电影列表与详情',
        icon: Icons.movie_creation_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const DyttPage(),
      ),
      ContentEntry(
        id: 'tvbox-cms',
        title: 'TVBox / CMS 自定义影视源',
        subtitle: '导入源配置、搜索影片、选择线路并使用统一播放器播放',
        icon: Icons.video_settings_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const TvBoxCatalogPage(),
      ),
      ContentEntry(
        id: 'local-media-library',
        requires: AppCapability.fileSystem,
        title: '本地媒体库',
        subtitle: '导入本地视频文件、管理索引并使用统一播放器播放',
        icon: Icons.folder_special_outlined,
        accent: ContentAccents.movie,
        builder: (_) => const LocalMediaLibraryPage(),
      ),
    ],
  ),
];
