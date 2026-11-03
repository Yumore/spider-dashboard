import 'package:dashboard/app/platform/app_capability.dart';
import 'package:dashboard/features/shared/ui/content_entry_section.dart';
import 'package:dashboard/features/reading/alexandria/alexandria_page.dart';
import 'package:dashboard/features/reading/book/view/book_shelf_page.dart';
import 'package:dashboard/features/reading/dodu_page.dart';
import 'package:dashboard/features/reading/easymygo/easymygo_page.dart';
import 'package:dashboard/features/reading/eso/eso_page.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/pages/home/feedbooks_home_page.dart';
import 'package:dashboard/features/reading/local_library/local_reading_library_page.dart';
import 'package:dashboard/features/reading/reading_web_page.dart';
import 'package:dashboard/features/reading/zhihu_demo/zhihu_demo_page.dart';
import 'package:dashboard/features/shared/ui/content_entry.dart';
import 'package:dashboard/features/shared/ui/content_tokens.dart';
import 'package:dashboard/views/novel/novel_home.dart';
import 'package:flutter/material.dart';

/// Reading business entries, grouped by what the user is trying to do:
/// choose a source engine, find a book, or tune the reading experience.
final List<ContentEntrySection> readingEntryCatalog = [
  ContentEntrySection(
    title: '书源与书库',
    description: '插件书源、Legado 书源与本地书架',
    entries: [
      ContentEntry(
        id: 'local-reading-library',
        requires: AppCapability.fileSystem,
        title: '电子书与教材',
        subtitle: '导入 EPUB / PDF · 目录 / 阅读进度 / 高亮与笔记',
        icon: Icons.menu_book_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const LocalReadingLibraryPage(),
      ),
      ContentEntry(
        id: 'easymygo',
        title: 'EasyMyGo 插件阅读',
        subtitle: '规则书源引擎 · 书架 / 搜索 / 详情 / 阅读',
        icon: Icons.extension,
        accent: ContentAccents.reading,
        builder: (_) => const EasyMyGoPage(),
      ),
      ContentEntry(
        id: 'book-shelf',
        title: '书源引擎阅读',
        subtitle: 'Legado 书源 · 书架 / 搜索 / 发现 / 目录 / 正文分页',
        icon: Icons.auto_stories_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const BookShelfPage(),
      ),
      ContentEntry(
        id: 'eso',
        title: 'ESO 全功能阅读',
        subtitle: '书源规则引擎 · 书架 / 跨源搜索 / 书源管理 / 阅读器',
        icon: Icons.menu_book_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const EsoPage(),
      ),
      ContentEntry(
        id: 'reading-novel-home',
        title: '书架与小说库',
        subtitle: '分类、详情、章节与阅读历史',
        icon: Icons.library_books_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const NovelHomePage(),
      ),
    ],
  ),
  ContentEntrySection(
    title: '找书与检索',
    description: '公开书库检索、下载与网页正文阅读',
    entries: [
      ContentEntry(
        id: 'alexandria',
        title: 'Alexandria 找书',
        subtitle: 'z-library、Library Genesis 与 Sci-Hub 检索与下载',
        icon: Icons.local_library_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const AlexandriaPage(),
      ),
      ContentEntry(
        id: 'feedbooks',
        requires: AppCapability.fileSystem,
        title: 'Feedbooks 电子书',
        subtitle: '公开书库 · 首页 / 探索 / 分类 / 详情 / 收藏 / 下载',
        icon: Icons.menu_book,
        accent: ContentAccents.reading,
        builder: (_) => const FeedbooksHomePage(),
      ),
      ContentEntry(
        id: 'reading-web',
        title: '网页章节阅读',
        subtitle: '加载章节、清理网页正文和自定义替换规则',
        icon: Icons.language_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const ReadingWebPage(),
      ),
    ],
  ),
  ContentEntrySection(
    title: '社区与偏好',
    description: '阅读社区演示与阅读器设置',
    entries: [
      ContentEntry(
        id: 'zhihu',
        title: '比乎阅读演示',
        subtitle: '关注、推荐、热榜与本地静态问答',
        icon: Icons.article_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const ZhihuDemoPage(),
      ),
      ContentEntry(
        id: 'dodu',
        title: 'DoDu 书架',
        subtitle: '原工程的书架、书城、我的三栏',
        icon: Icons.bookmarks_outlined,
        accent: ContentAccents.reading,
        builder: (_) => const DoduPage(),
      ),
      ContentEntry(
        id: 'reader-settings',
        title: '阅读偏好',
        subtitle: '字体、背景、翻页和状态栏设置',
        icon: Icons.tune_outlined,
        accent: ContentAccents.reading,
        onTap: (context) =>
            Navigator.of(context).pushNamed('/NovelReaderSettings'),
      ),
    ],
  ),
];
