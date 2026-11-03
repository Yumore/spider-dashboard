import 'package:dashboard/features/shared/ui/content_entry_section.dart';
import 'package:dashboard/features/novel/flutternovel/flutternovel_page.dart';
import 'package:dashboard/features/reading/book/view/book_shelf_page.dart';
import 'package:dashboard/features/reading/book/view/source_manage_page.dart';
import 'package:dashboard/features/reading/easymygo/easymygo_page.dart';
import 'package:dashboard/features/reading/eso/eso_page.dart';
import 'package:dashboard/features/short_drama/creator/creator_page.dart';
import 'package:dashboard/features/shared/ui/content_entry.dart';
import 'package:dashboard/features/shared/ui/content_tokens.dart';
import 'package:dashboard/views/novel/novel_home.dart';
import 'package:flutter/material.dart';

/// Novel business entries: the local library and the network-novel reader.
final List<ContentEntrySection> novelEntryCatalog = [
  ContentEntrySection(
    title: '小说与 AI 漫剧创作',
    description: '本机保存作品设定、章节剧本和漫剧分镜草稿',
    entries: [
      ContentEntry(
        id: 'novel-ai-drama-creator',
        title: '创作工作台',
        subtitle: '小说 / 短剧 / AI 漫剧 · 本地项目与用户自配模型',
        icon: Icons.auto_awesome_outlined,
        accent: ContentAccents.novel,
        builder: (_) => const CreatorPage(),
      ),
    ],
  ),
  ContentEntrySection(
    title: '小说库',
    description: '本地书架与网络小说阅读',
    entries: [
      ContentEntry(
        id: 'novel-home',
        title: '打开小说库',
        subtitle: '分类、排行、详情、章节与阅读历史',
        icon: Icons.auto_stories_outlined,
        accent: ContentAccents.novel,
        builder: (_) => const NovelHomePage(),
      ),
      ContentEntry(
        id: 'flutternovel',
        title: '网络小说',
        subtitle: '书架 / 搜索 / 三种翻页动画',
        icon: Icons.import_contacts_outlined,
        accent: ContentAccents.novel,
        builder: (_) => const FlutterNovelPage(),
      ),
    ],
  ),
  ContentEntrySection(
    title: '小说源与阅读引擎',
    description: '管理 Legado 书源，或使用规则源搜索和阅读',
    entries: [
      ContentEntry(
        id: 'book-shelf-source-engine',
        title: 'Legado 书源阅读',
        subtitle: '书架 / 跨源搜索 / 发现 / 章节阅读',
        icon: Icons.auto_stories_outlined,
        accent: ContentAccents.novel,
        builder: (_) => const BookShelfPage(),
      ),
      ContentEntry(
        id: 'book-source-manage',
        title: '书源管理',
        subtitle: '导入 Legado JSON、管理启用状态或从公开仓库导入',
        icon: Icons.source_outlined,
        accent: ContentAccents.novel,
        builder: (_) => const SourceManagePage(),
      ),
      ContentEntry(
        id: 'easymygo-source-engine',
        title: 'EasyMyGo 规则源',
        subtitle: '插件书源、搜索、书架与阅读',
        icon: Icons.extension_outlined,
        accent: ContentAccents.novel,
        builder: (_) => const EasyMyGoPage(),
      ),
      ContentEntry(
        id: 'eso-source-engine',
        title: 'ESO 书源引擎',
        subtitle: '跨源搜索、规则管理与阅读器',
        icon: Icons.menu_book_outlined,
        accent: ContentAccents.novel,
        builder: (_) => const EsoPage(),
      ),
    ],
  ),
];
