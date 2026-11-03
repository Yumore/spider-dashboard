import 'package:dashboard/app/app_setting.dart';
import 'package:dashboard/app/platform/app_messenger.dart';
import 'package:dashboard/app/platform/app_platform.dart';
import 'package:dashboard/app/platform/app_platform_bootstrap.dart';
import 'package:dashboard/app/config_helper.dart';
import 'package:dashboard/app/utils.dart';
import 'package:dashboard/features/content_hub/content_hub_page.dart';
import 'package:dashboard/features/reading/book/analyzer/js_analyzer.dart';
import 'package:dashboard/sql/comic_down.dart';
import 'package:dashboard/sql/comic_history.dart';
import 'package:dashboard/views/comic/comic_home.dart';
import 'package:dashboard/views/news/news_home.dart';
import 'package:dashboard/views/novel/novel_home.dart';
import 'package:dashboard/views/setting_page.dart';
import 'package:dashboard/views/settings/comic_reader_settings.dart';
import 'package:dashboard/views/settings/novel_reader_settings.dart';
import 'package:dashboard/views/user/login_page.dart';
import 'package:dashboard/views/user/personal_page.dart';
import 'package:dashboard/views/user/user_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app/app_theme.dart';
import 'app/user_info.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 平台初始化：Web/桌面需要先安装对应的 SQLite databaseFactory。
  // 即使初始化失败也允许应用进入内容中心（数据功能降级）。
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

Future initDatabase() async {
  try {
    await _openAppDatabase();
  } catch (error, stackTrace) {
    // 平台没有可用 SQLite（例如 Web 未安装 wasm）时允许应用继续启动；
    // 历史/下载记录等依赖数据库的旧版页面此时不可用（会抛空值错误）。
    debugPrint('SQLite 初始化失败：$error\n$stackTrace');
  }
}

Future _openAppDatabase() async {
  var databasesPath = await getDatabasesPath();
  // File(databasesPath+"/nsplayer.db").deleteSync();
  var db = await openDatabase(
    databasesPath + "/comic_history.db",
    version: 1,
    onCreate: (Database _db, int version) async {
      await _db.execute('''
create table $comicHistoryTable ( 
  $comicHistoryColumnComicID integer primary key not null, 
  $comicHistoryColumnChapterID integer not null,
  $comicHistoryColumnPage double not null,
  $comicHistoryMode integer not null)
''');

      await _db.execute('''
create table $comicDownloadTableName (
$comicDownloadColumnChapterID integer primary key not null,
$comicDownloadColumnChapterName text not null,
$comicDownloadColumnComicID integer not null,
$comicDownloadColumnComicName text not null,
$comicDownloadColumnStatus integer not null,
$comicDownloadColumnVolume text not null,
$comicDownloadColumnPage integer ,
$comicDownloadColumnCount integer ,
$comicDownloadColumnSavePath text ,
$comicDownloadColumnUrls text )
''');
    },
  );

  ComicHistoryProvider.database = db;
  ComicDownloadProvider.database = db;
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: AppMessenger.key,
      title: '动漫之家Flutter',
      theme: ThemeData(
        primarySwatch: Provider.of<AppTheme>(context).themeColor,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      themeMode: Provider.of<AppTheme>(context).themeMode,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Provider.of<AppTheme>(context).themeColor,
        ).copyWith(secondary: Provider.of<AppTheme>(context).themeColor),
      ),
      home: const MyHomePage(),
      initialRoute: "/",
      routes: {
        "/Setting": (_) => const SettingPage(),
        "/Login": (_) => const LoginPage(),
        "/User": (_) => const UserPage(),
        "/ComicReaderSettings": (_) => const ComicReaderSettings(),
        "/NovelReaderSettings": (_) => const NovelReaderSettings(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  static NewsHomePage? newsPage;
  static NovelHomePage? novelPage;
  List<Widget> pages = [
    const ContentHubPage(),
    const ComicHomePage(),
    Container(),
    Container(),
    const PersonalPage(),
  ];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    checkUpdate();
  }

  Future<void> checkUpdate() async {
    if (!AppPlatform.supportsSelfUpdate) {
      // Web/桌面/鸿蒙没有应用内安装包的更新链路。
      return;
    }
    final newVer = await Utils.checkVersion();
    if (!mounted || newVer.message == null) {
      return;
    }
    if (await Utils.showAlertDialogAsync(
      context,
      const Text('有新版本可以更新'),
      Text(newVer.message!),
    )) {
      final url = AppPlatform.isAndroid ? newVer.android_url : newVer.ios_url;
      if (url == null) {
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: (index) {
          setState(() {
            if (index == 2 && newsPage == null) {
              newsPage = const NewsHomePage();
              pages[2] = newsPage ?? const NewsHomePage();
            }
            if (index == 3 && novelPage == null) {
              novelPage = const NovelHomePage();
              pages[3] = novelPage ?? const NovelHomePage();
            }
            _index = index;
          });
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            label: "内容",
            icon: Icon(Icons.dashboard_outlined),
          ),
          BottomNavigationBarItem(label: "漫画", icon: Icon(Icons.library_books)),
          BottomNavigationBarItem(label: "新闻", icon: Icon(Icons.whatshot)),
          BottomNavigationBarItem(label: "轻小说", icon: Icon(Icons.book)),
          BottomNavigationBarItem(
            label: "我的",
            icon: Icon(Icons.account_circle),
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          // NavigationRail(
          //   backgroundColor: Theme.of(context).bottomAppBarColor,
          //     onDestinationSelected: (int index) {
          //       setState(() {
          //         _index = index;
          //       });
          //     },
          //     labelType: NavigationRailLabelType.all,
          //     destinations: [
          //       NavigationRailDestination(
          //         icon: Icon(Icons.library_books),
          //         label: Text('漫画'),
          //       ),
          //       NavigationRailDestination(
          //         icon: Icon(Icons.whatshot),
          //         label: Text('新闻'),
          //       ),
          //       NavigationRailDestination(
          //         icon: Icon(Icons.book),
          //         label: Text('轻小说'),
          //       ),
          //       NavigationRailDestination(
          //         icon: Icon(Icons.account_circle),
          //         label: Text('我的'),
          //       ),
          //     ],
          //     selectedIndex: _index),
          // VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
