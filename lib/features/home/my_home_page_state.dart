import 'package:dashboard/app/platform/app_platform.dart';
import 'package:dashboard/app/app_navigation.dart';
import 'package:dashboard/app/utils.dart';
import 'package:dashboard/features/anime/anime_module_page.dart';
import 'package:dashboard/features/home/my_home_page.dart';
import 'package:dashboard/features/live/live_module_page.dart';
import 'package:dashboard/features/reading/book/view/book_shelf_page.dart';
import 'package:dashboard/features/short_drama/short_drama_module_page_export.dart';
import 'package:dashboard/views/comic/comic_home.dart';
import 'package:dashboard/views/user/personal_page.dart';
import 'package:guomu/guomu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MyHomePageState extends State<MyHomePage> {
  static const MethodChannel _guomuEntryChannel = MethodChannel(
    'com.yumore.dashboard/guomu-entry',
  );

  static const List<String> _labels = <String>[
    '动漫',
    '漫画',
    '直播',
    '短剧',
    '书架',
    '我的',
  ];

  static const List<IconData> _icons = <IconData>[
    Icons.home_outlined,
    Icons.bookmark_border,
    Icons.live_tv_outlined,
    Icons.videocam_outlined,
    Icons.menu_book_outlined,
    Icons.person_outline,
  ];

  static const List<IconData> _selectedIcons = <IconData>[
    Icons.home,
    Icons.bookmark,
    Icons.live_tv,
    Icons.videocam,
    Icons.menu_book,
    Icons.person,
  ];

  static const List<Widget> _pages = <Widget>[
    AnimeModulePage(),
    ComicHomePage(),
    LiveModulePage(),
    ShortDramaModulePage(),
    BookShelfPage(),
    PersonalPage(),
  ];

  int _index = 0;
  bool _openingGuomu = false;

  @override
  void initState() {
    super.initState();
    _guomuEntryChannel.setMethodCallHandler(_handleGuomuEntryCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeInitialGuomuLink();
    });
    _checkForUpdates();
  }

  @override
  void dispose() {
    _guomuEntryChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<Object?> _handleGuomuEntryCall(MethodCall call) async {
    if (call.method == 'open') {
      _openGuomuFromLink(call.arguments?.toString());
    }
    return null;
  }

  Future<void> _consumeInitialGuomuLink() async {
    try {
      final link = await _guomuEntryChannel.invokeMethod<String>(
        'getInitialLink',
      );
      _openGuomuFromLink(link);
    } on MissingPluginException {
      // Web and desktop do not register the native deep-link bridge.
    } on PlatformException catch (error) {
      debugPrint('果幕初始链接读取失败：${error.message}');
    }
  }

  void _openGuomuFromLink(String? value) {
    final uri = Uri.tryParse(value ?? '');
    if (uri?.scheme != 'guomu' ||
        !mounted ||
        GuomuEmbeddedPage.isActive ||
        _openingGuomu) {
      return;
    }
    final navigator = dashboardNavigatorKey.currentState;
    if (navigator == null) return;

    _openingGuomu = true;
    navigator
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => GuomuEmbeddedPage(
              onClose: () {
                navigator.maybePop();
              },
            ),
          ),
        )
        .whenComplete(() => _openingGuomu = false);
  }

  void _selectPage(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  Future<void> _checkForUpdates() async {
    if (!AppPlatform.supportsSelfUpdate) return;

    final latestVersion = await Utils.checkVersion();
    if (!mounted || latestVersion.message == null) return;
    final shouldUpdate = await Utils.showAlertDialogAsync(
      context,
      const Text('有新版本可以更新'),
      Text(latestVersion.message!),
    );
    if (!shouldUpdate) return;

    final downloadUrl = AppPlatform.isAndroid
        ? latestVersion.android_url
        : latestVersion.ios_url;
    if (downloadUrl == null) return;
    await launchUrl(
      Uri.parse(downloadUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _buildPage() => IndexedStack(index: _index, children: _pages);

  Widget _buildBottomNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.bottomNavigationBarTheme.backgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerTheme.color ?? Colors.black12),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _index,
        onTap: _selectPage,
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: <BottomNavigationBarItem>[
          for (var i = 0; i < _labels.length; i++)
            BottomNavigationBarItem(
              label: _labels[i],
              icon: Icon(_icons[i]),
              activeIcon: Icon(_selectedIcons[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationRail(
      backgroundColor: theme.colorScheme.surface,
      selectedIndex: _index,
      onDestinationSelected: _selectPage,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
      unselectedIconTheme: IconThemeData(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      destinations: <NavigationRailDestination>[
        for (var i = 0; i < _labels.length; i++)
          NavigationRailDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_selectedIcons[i]),
            label: Text(_labels[i]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 800;
        return Scaffold(
          body: useRail
              ? Row(
                  children: <Widget>[
                    _buildNavigationRail(context),
                    VerticalDivider(
                      width: 1,
                      color: Theme.of(context).dividerTheme.color,
                    ),
                    Expanded(child: _buildPage()),
                  ],
                )
              : _buildPage(),
          bottomNavigationBar: useRail
              ? null
              : _buildBottomNavigationBar(context),
        );
      },
    );
  }
}
