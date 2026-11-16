import 'package:dashboard/app/app_navigation.dart';
import 'package:dashboard/app/app_theme.dart';
import 'package:dashboard/app/platform/app_messenger.dart';
import 'package:dashboard/features/home/my_home_page.dart';
import 'package:dashboard/views/setting_page.dart';
import 'package:dashboard/views/settings/comic_reader_settings.dart';
import 'package:dashboard/views/settings/novel_reader_settings.dart';
import 'package:dashboard/views/user/login_page.dart';
import 'package:dashboard/views/user/user_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();
    return MaterialApp(
      navigatorKey: dashboardNavigatorKey,
      scaffoldMessengerKey: AppMessenger.key,
      title: '动漫之家Flutter',
      theme: appTheme.themeFor(Brightness.light),
      darkTheme: appTheme.themeFor(Brightness.dark),
      themeMode: appTheme.themeMode,
      home: const MyHomePage(),
      initialRoute: '/',
      routes: {
        '/Setting': (_) => const SettingPage(),
        '/Login': (_) => const LoginPage(),
        '/User': (_) => const UserPage(),
        '/ComicReaderSettings': (_) => const ComicReaderSettings(),
        '/NovelReaderSettings': (_) => const NovelReaderSettings(),
      },
    );
  }
}
