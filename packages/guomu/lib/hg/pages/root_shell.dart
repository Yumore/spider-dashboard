import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_flags.dart';
import '../app_metadata.dart';
import '../auth/app_controllers.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_download_manager.dart';
import '../services/hg_deep_link_service.dart';
import '../services/hg_notification_service.dart';
import '../services/hg_settings.dart';
import '../utils/hg_update_service.dart';
import 'category_page.dart';
import 'home_page.dart';
import 'posts_page.dart';
import 'profile_page.dart';
import 'short_video_page.dart';
import 'review_prompt.dart';
import 'rank_page.dart';
import 'settings_page.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/hg_pressable.dart';
import 'update_sheet.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  static const _releaseSeenKey = 'guomu.release.seen';
  static const _updateCheckedKey = 'guomu.update.last_checked.v1';

  static const _pages = [
    HomePage(),
    CategoryPage(),
    PostsPage(showBack: false),
    RankPage(),
    ProfilePage(),
  ];

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, '首页'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, '剧场'),
    (Icons.forum_outlined, Icons.forum_rounded, '吃瓜'),
    (Icons.emoji_events_outlined, Icons.emoji_events_rounded, '榜单'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  int _index = 0;
  final Set<int> _visited = {0};
  bool _sourceSheetShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      unawaited(maybeShowHgReviewPrompt(context, prefs));
      unawaited(
        HgDeepLinkService.initialize(
          onLink: (uri) async {
            final id = int.tryParse(
              uri.pathSegments.isEmpty ? '' : uri.pathSegments.last,
            );
            if (id == null || !mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShortVideoPage(videoIds: [id]),
              ),
            );
          },
        ),
      );
      final downloads = context.read<HgDownloadManager>();
      downloads.onUpdateFound = (task, count) async {
        if (prefs.getBool(HgSettingsKeys.notificationsEnabled) ?? true) {
          await HgNotificationService.showDramaUpdate(task, count);
        }
      };
      downloads.onDownloadCompleted = (task) async {
        if (prefs.getBool(HgSettingsKeys.notificationsEnabled) ?? true) {
          await HgNotificationService.showOfflineReady(task);
        }
      };
      _runStartupChecks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HgDeepLinkService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<HgDownloadManager>().checkForUpdates());
    }
  }

  Future<void> _runStartupChecks() async {
    if (kIsWeb && kHgWebPreviewOnly) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      await showHgAdaptiveSheet<void>(
        context,
        child: const _WebPreviewNotice(),
      );
    }
    await _maybeShowReleaseNotes();
    if (mounted) await _maybeCheckUpdate();
    if (mounted) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) await context.read<HgDownloadManager>().checkForUpdates();
    }
  }

  Future<void> _maybeShowReleaseNotes() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_releaseSeenKey) == HgAppMetadata.versionLabel) return;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await showHgAdaptiveSheetBuilder<void>(
      context,
      childScrollable: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      initialSize: 0.62,
      builder: (_) => const HgReleaseNotesSheet(),
    );
    await prefs.setString(_releaseSeenKey, HgAppMetadata.versionLabel);
  }

  Future<void> _maybeCheckUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final checkedAt = DateTime.tryParse(
      prefs.getString(_updateCheckedKey) ?? '',
    );
    if (checkedAt != null &&
        DateTime.now().difference(checkedAt) < const Duration(hours: 12)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    try {
      final result = await HgUpdateService.checkLatest();
      await prefs.setString(
        _updateCheckedKey,
        DateTime.now().toIso8601String(),
      );
      if (mounted && result.hasUpdate) {
        await showHgUpdateResultSheet(context, result, automatic: true);
      }
    } catch (_) {
      // 自动检查失败不打扰启动，用户仍可在设置页手动检查。
    }
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  Widget _body() {
    return IndexedStack(
      index: _index,
      children: List.generate(
        _pages.length,
        (index) =>
            _visited.contains(index) ? _pages[index] : const SizedBox.shrink(),
      ),
    );
  }

  Widget _appShell() {
    return Scaffold(
      body: _body(),
      bottomNavigationBar: _AppBottomBar(
        index: _index,
        items: _items,
        onSelected: _select,
        onClose: widget.onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = context.watch<SourceController>();
    if (source.needsManual && !source.isDiscovering && !_sourceSheetShown) {
      _sourceSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showHgAdaptiveSheetBuilder<void>(
          context,
          isDismissible: false,
          enableDrag: false,
          childScrollable: true,
          barrierColor: Colors.black.withValues(alpha: 0.42),
          initialSize: 0.68,
          maxSize: 0.94,
          builder: (_) => const HgSourceEditorSheet(recovery: true),
        );
      });
    }
    return PopScope(
      canPop: _index == 0 && widget.onClose == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
        if (!didPop && _index == 0) widget.onClose?.call();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          if (!wide) return _appShell();
          final dark = Theme.of(context).brightness == Brightness.dark;
          return ColoredBox(
            color: dark ? const Color(0xFF050505) : const Color(0xFFE9E9EB),
            child: Center(
              child: Container(
                width: 560,
                height: constraints.maxHeight - 32,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 40,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: _appShell(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WebPreviewNotice extends StatelessWidget {
  const _WebPreviewNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: HgColors.orange.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.open_in_new_rounded,
              color: HgColors.orange,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '这是果幕的网页预览',
            style: TextStyle(
              color: context.hgOnSurface,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ' GitHub Pages 仅用于浏览界面预览，不提供播放服务。请前往 GitHub Releases 下载安卓 APK 或未签名 IPA；iOS 安装包需要自行签名。',
            style: TextStyle(
              color: context.hgMuted,
              fontSize: 13,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(kHgLatestReleaseUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download_rounded, size: 19),
              label: const Text('前往 Releases 下载'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('先看看界面'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBottomBar extends StatelessWidget {
  const _AppBottomBar({
    required this.index,
    required this.items,
    required this.onSelected,
    this.onClose,
  });

  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onSelected;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              ...List.generate(items.length, (itemIndex) {
                final selected = itemIndex == index;
                final item = items[itemIndex];
                final color = selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.42);
                return Expanded(
                  child: Semantics(
                    selected: selected,
                    button: true,
                    label: item.$3,
                    child: HgInkWell(
                      onTap: () => onSelected(itemIndex),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOut,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: Icon(
                              selected ? item.$2 : item.$1,
                              key: ValueKey<bool>(selected),
                              size: 22,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.$3,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (onClose != null)
                SizedBox(
                  width: 52,
                  child: IconButton(
                    tooltip: '返回 Dashboard',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
