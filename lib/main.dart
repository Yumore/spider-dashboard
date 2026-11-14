import 'package:dashboard/app/app_setting.dart';
import 'package:dashboard/app/app_theme.dart';
import 'package:dashboard/app/config_helper.dart';
import 'package:dashboard/app/my_app.dart';
import 'package:dashboard/app/platform/app_platform_bootstrap.dart';
import 'package:dashboard/app/user_info.dart';
import 'package:dashboard/features/comic/picacomic/core/comic_source_registry.dart';
import 'package:dashboard/features/reading/book/analyzer/js_analyzer.dart';
import 'package:dashboard/sql/comic_down.dart';
import 'package:dashboard/sql/comic_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppPlatformBootstrap.initialize();
  } catch (error, stackTrace) {
    debugPrint('平台数据库工厂初始化失败：$error\n$stackTrace');
  }
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
  } catch (error) {
    debugPrint('系统 UI 样式设置不可用：$error');
  }

  ConfigHelper.prefs = await SharedPreferences.getInstance();
  JsEngine.instance.enabled =
      ConfigHelper.prefs.getBool(JsEngine.enabledPreferenceKey) ?? false;
  await initDatabase();
  await ComicSourceRegistry.init();
  if (ComicSourceRegistry.tagDictionaryLoadError case final error?) {
    debugPrint('PicaComic 标签词典不可用：$error');
  }
  for (final entry in ComicSourceRegistry.sourceInitializationErrors.entries) {
    debugPrint('PicaComic 来源 ${entry.key} 初始化失败：${entry.value}');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppTheme>(
          create: (_) => AppTheme(),
          lazy: false,
        ),
        ChangeNotifierProvider<AppUserInfo>(
          create: (_) => AppUserInfo(),
          lazy: false,
        ),
        ChangeNotifierProvider<AppSetting>(
          create: (_) => AppSetting(),
          lazy: false,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> initDatabase() async {
  try {
    await _openAppDatabase();
  } catch (error, stackTrace) {
    debugPrint('SQLite 初始化失败：$error\n$stackTrace');
  }
}

Future<void> _openAppDatabase() async {
  final databasesPath = await getDatabasesPath();
  final database = await openDatabase(
    '$databasesPath/comic_history.db',
    version: 1,
    onCreate: (Database database, int version) async {
      await database.execute('''
create table $comicHistoryTable (
  $comicHistoryColumnComicID integer primary key not null,
  $comicHistoryColumnChapterID integer not null,
  $comicHistoryColumnPage double not null,
  $comicHistoryMode integer not null)
''');

      await database.execute('''
create table $comicDownloadTableName (
$comicDownloadColumnChapterID integer primary key not null,
$comicDownloadColumnChapterName text not null,
$comicDownloadColumnComicID integer not null,
$comicDownloadColumnComicName text not null,
$comicDownloadColumnStatus integer not null,
$comicDownloadColumnVolume text not null,
$comicDownloadColumnPage integer,
$comicDownloadColumnCount integer,
$comicDownloadColumnSavePath text,
$comicDownloadColumnUrls text)
''');
    },
  );

  ComicHistoryProvider.database = database;
  ComicDownloadProvider.database = database;
}
