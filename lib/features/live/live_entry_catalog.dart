import 'package:dashboard/features/shared/ui/content_entry_section.dart';
import 'package:dashboard/features/live/billd_live_page.dart';
import 'package:dashboard/features/live/easy_tv_live/easy_tv_page.dart';
import 'package:dashboard/features/live/my_tv/my_tv_page.dart';
import 'package:dashboard/features/live/pure_live/pure_live_entry.dart';
import 'package:dashboard/features/live/pure_live_nas/pure_live_nas_page.dart';
import 'package:dashboard/features/live/simple_live_entry.dart';
import 'package:dashboard/features/live/twitch_media/twitch_media_catalog_page.dart';
import 'package:dashboard/features/shared/ui/content_entry.dart';
import 'package:dashboard/features/shared/ui/content_tokens.dart';
import 'package:flutter/material.dart';

/// Live-streaming sites. Subscription channels stay on the page itself.
final List<ContentEntrySection> liveEntryCatalog = [
  ContentEntrySection(
    title: '直播站点',
    description: '在线直播间与 IPTV 订阅源',
    entries: [
      ContentEntry(
        id: 'twitch-media',
        title: 'Twitch 回看与片段',
        subtitle: '公开频道 VOD、Clip 浏览与统一播放器播放',
        icon: Icons.video_library_outlined,
        accent: ContentAccents.live,
        builder: (_) => const TwitchMediaCatalogPage(),
      ),
      ContentEntry(
        id: 'pure-live-nas',
        title: 'Pure Live NAS · 自托管管理台',
        subtitle: '五平台聚合 · 账号托管 · 关注同步 · 弹幕与直播代理',
        icon: Icons.dns_outlined,
        accent: ContentAccents.live,
        builder: (_) => const PureLiveNasPage(),
      ),
      ContentEntry(
        id: 'simple-live',
        title: 'SimpleLive · 多平台直播',
        subtitle: 'B站、斗鱼、虎牙、抖音直播 · 弹幕 · 关注与历史',
        icon: Icons.live_tv_outlined,
        accent: ContentAccents.live,
        builder: (_) => const SimpleLiveEmbeddedPage(),
      ),
      ContentEntry(
        id: 'pure-live',
        title: 'Pure Live · 多平台直播',
        subtitle: '34 个平台 · 弹幕 · 录制 · 多画面 · IPTV · DLNA',
        icon: Icons.live_tv,
        accent: ContentAccents.live,
        builder: (_) => const PureLiveEmbeddedPage(),
      ),
      ContentEntry(
        id: 'billd-live',
        title: 'Billd 直播',
        subtitle: '查看在线直播间',
        icon: Icons.live_tv,
        accent: ContentAccents.live,
        builder: (_) => const BilldLivePage(),
      ),
      ContentEntry(
        id: 'my-tv',
        title: '我的电视',
        subtitle: 'IPTV 直播源 · 分组换台 · XMLTV 节目单',
        icon: Icons.live_tv,
        accent: ContentAccents.live,
        builder: (_) => const MyTvPage(),
      ),
      ContentEntry(
        id: 'easy-tv',
        title: 'EasyTV 直播',
        subtitle: 'm3u/txt 订阅 · 线路失败切换 · 源管理',
        icon: Icons.live_tv_outlined,
        accent: ContentAccents.live,
        builder: (_) => const EasyTvPage(),
      ),
    ],
  ),
];
