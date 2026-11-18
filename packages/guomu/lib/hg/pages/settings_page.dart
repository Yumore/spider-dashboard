import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/hg_api.dart';
import '../app_metadata.dart';
import '../auth/app_controllers.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../services/hg_background_worker.dart';
import '../services/hg_notification_service.dart';
import '../services/hg_settings.dart';
import '../utils/hg_download_manager.dart';
import '../utils/hg_media_cache.dart';
import '../utils/hg_update_service.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/secure_cover.dart';
import 'about_page.dart';
import 'downloads_page.dart';
import 'login_sheet.dart';
import 'update_history_page.dart';
import 'update_sheet.dart';
import '../widgets/hg_pressable.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _cacheBytes = 0;
  bool _clearingCache = false;
  bool _checkingUpdate = false;
  String _cacheMessage = '';
  String _updateMessage = '';
  bool _notificationsEnabled = true;
  bool _autoUpdateDownloads = true;
  bool _backgroundUpdates = true;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled =
          prefs.getBool(HgSettingsKeys.notificationsEnabled) ?? true;
      _autoUpdateDownloads =
          prefs.getBool(HgSettingsKeys.autoUpdateDownloads) ?? true;
      _backgroundUpdates =
          prefs.getBool(HgSettingsKeys.backgroundUpdates) ?? true;
    });
  }

  Future<void> _setNotifications(bool value) async {
    var next = value;
    if (value) {
      final granted = await HgNotificationService.requestPermissions();
      if (!granted) {
        next = false;
        if (mounted) {
          showHgSnack(context, '通知权限未开启，请在系统设置中允许果幕通知');
        }
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(HgSettingsKeys.notificationsEnabled, next);
    if (mounted) setState(() => _notificationsEnabled = next);
  }

  Future<void> _setAutoUpdateDownloads(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(HgSettingsKeys.autoUpdateDownloads, value);
    if (mounted) setState(() => _autoUpdateDownloads = value);
  }

  Future<void> _setBackgroundUpdates(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(HgSettingsKeys.backgroundUpdates, value);
    await HgBackgroundWorker.syncSchedule();
    if (mounted) setState(() => _backgroundUpdates = value);
  }

  Future<void> _loadCacheSize() async {
    final api = context.read<HgApi>();
    final downloads = context.read<HgDownloadManager>();
    final contentBytes = await api.cacheSizeBytes();
    final mediaBytes = await HgMediaCache.sizeBytes();
    final downloadBytes = await downloads.sizeBytes();
    if (mounted) {
      setState(() => _cacheBytes = contentBytes + mediaBytes + downloadBytes);
    }
  }

  Future<void> _clearCache() async {
    if (_clearingCache) return;
    final confirmed = await showHgConfirmSheet(
      context,
      title: '清除缓存？',
      message: '会清除内容、封面和已预加载的视频分片，不会退出登录，也不会删除收藏、历史或资料。',
      confirmLabel: '清除缓存',
      icon: Icons.cleaning_services_outlined,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _clearingCache = true;
      _cacheMessage = '';
    });
    try {
      await context.read<HgApi>().clearContentCache();
      await HgMediaCache.clear();
      HgCoverRepository.instance.clear();
      if (mounted) {
        setState(() {
          _cacheBytes = 0;
          _cacheMessage = '缓存已清除';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _cacheMessage = cleanError(error));
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showHgConfirmSheet(
      context,
      title: '退出登录？',
      message: '退出后本机仍会保留离线缓存、追剧进度和观看历史。',
      confirmLabel: '退出登录',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) return;
    await context.read<AuthController>().logout();
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _editSource() async {
    final changed = await showHgAdaptiveSheetBuilder<bool>(
      context,
      childScrollable: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      initialSize: 0.64,
      builder: (_) => const HgSourceEditorSheet(),
    );
    if (changed == true && mounted) {
      HgCoverRepository.instance.clear();
      await context.read<HgApi>().clearContentCache();
    }
  }

  void _openReleaseHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const UpdateHistoryPage()));
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() {
      _checkingUpdate = true;
      _updateMessage = '';
    });
    try {
      final result = await HgUpdateService.checkLatest();
      if (!mounted) return;
      await showHgUpdateResultSheet(context, result);
    } catch (error) {
      if (mounted) {
        setState(() => _updateMessage = error.toString());
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _showThemeSheet() async {
    await showHgAdaptiveSheetBuilder<void>(
      context,
      childScrollable: true,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (_) => const _ThemeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final source = context.watch<SourceController>();
    final theme = context.watch<ThemeController>();
    final downloads = context.watch<HgDownloadManager>();
    final user = auth.user;
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      appBar: AppBar(
        backgroundColor: context.hgSurfaceLow,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SettingsGroup(
            title: '账号',
            children: [
              if (auth.isLoggedIn && user != null)
                _SettingsRow(
                  leading: HgAvatar(
                    name: user.nickname,
                    url: user.avatar,
                    size: 42,
                    color: colorFromHex(user.avatarColor),
                  ),
                  title: user.nickname,
                  subtitle: 'ID：${user.id}',
                )
              else
                _SettingsRow(
                  leading: const _RowIcon(Icons.person_outline_rounded),
                  title: '登录黄果账号',
                  subtitle: '同步追剧、历史、点赞和消息',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLoginSheet(context),
                ),
              if (auth.isLoggedIn && user != null) ...[
                const _SettingsDivider(),
                _SettingsRow(
                  leading: const _RowIcon(
                    Icons.logout_rounded,
                    color: Color(0xFFC64F45),
                  ),
                  title: '退出登录',
                  titleColor: const Color(0xFFC64F45),
                  subtitle: '仅退出当前账号，不删除缓存',
                  onTap: _logout,
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: '播放与缓存',
            children: [
              _SettingsRow(
                leading: const _RowIcon(Icons.download_for_offline_outlined),
                title: '我的下载',
                subtitle: downloads.tasks.isEmpty
                    ? '离线缓存、下载进度与网速'
                    : '${downloads.tasks.length} 部短剧 · ${downloads.tasks.where((item) => item.isDownloading).length} 个任务进行中',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DownloadsPage(),
                  ),
                ),
              ),
              const _SettingsDivider(),
              _SettingsRow(
                leading: const _RowIcon(Icons.cleaning_services_outlined),
                title: _clearingCache ? '正在清理…' : '清除缓存',
                subtitle: _cacheMessage.isNotEmpty
                    ? _cacheMessage
                    : _formatBytes(_cacheBytes),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _clearingCache ? null : _clearCache,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: '通知与后台',
            children: [
              _SettingsRow(
                leading: const _RowIcon(Icons.notifications_none_rounded),
                title: '追更通知',
                subtitle: _notificationsEnabled
                    ? '剧集更新时发送本机通知'
                    : '已关闭，不再发送更新通知',
                trailing: Switch.adaptive(
                  value: _notificationsEnabled,
                  onChanged: _setNotifications,
                ),
              ),
              const _SettingsDivider(),
              _SettingsRow(
                leading: const _RowIcon(Icons.admin_panel_settings_outlined),
                title: '系统权限',
                subtitle: '通知、实时活动、后台 App 刷新和本地网络',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: openAppSettings,
              ),
              const _SettingsDivider(),
              _SettingsRow(
                leading: const _RowIcon(Icons.system_update_alt_rounded),
                title: '自动缓存新集',
                subtitle: _autoUpdateDownloads ? '新剧集出现后自动加入下载队列' : '仅提醒，不自动下载',
                trailing: Switch.adaptive(
                  value: _autoUpdateDownloads,
                  onChanged: _setAutoUpdateDownloads,
                ),
              ),
              const _SettingsDivider(),
              _SettingsRow(
                leading: const _RowIcon(Icons.sync_lock_rounded),
                title: '后台检查追更',
                subtitle: _backgroundUpdates ? '系统允许时每天检查一次' : '仅在打开应用时检查',
                trailing: Switch.adaptive(
                  value: _backgroundUpdates,
                  onChanged: _setBackgroundUpdates,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: '外观',
            children: [
              _SettingsRow(
                leading: const _RowIcon(Icons.brightness_6_outlined),
                title: '显示模式',
                subtitle: switch (theme.mode) {
                  ThemeMode.light => '浅色',
                  ThemeMode.dark => '深色',
                  ThemeMode.system => '跟随系统',
                },
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showThemeSheet,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: '内容源',
            children: [
              _SettingsRow(
                leading: const _RowIcon(Icons.dns_outlined),
                title: '内容源 · ${source.sources.length} 个',
                subtitle: source.baseUrl,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _editSource,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: '关于与更新',
            children: [
              _SettingsRow(
                leading: const _RowIcon(Icons.sync_rounded),
                title: _checkingUpdate ? '正在检查更新…' : '检查更新',
                subtitle: _updateMessage.isNotEmpty
                    ? _updateMessage
                    : '通过 GitHub Releases 获取最新版本',
                trailing: _checkingUpdate
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _checkingUpdate ? null : _checkUpdate,
              ),
              const _SettingsDivider(),
              _SettingsRow(
                leading: const _RowIcon(Icons.info_outline_rounded),
                title: '版本号',
                subtitle: HgAppMetadata.versionLabel,
                trailing: const SizedBox.shrink(),
              ),
              const _SettingsDivider(),
              _SettingsRow(
                leading: const _RowIcon(Icons.new_releases_outlined),
                title: '更新记录',
                subtitle:
                    '当前 ${HgAppMetadata.versionLabel} · ${HgAppMetadata.releaseTitle}',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openReleaseHistory,
              ),
              const _SettingsDivider(),
              _SettingsRow(
                leading: const _RowIcon(Icons.code_rounded),
                title: '关于果幕',
                subtitle: '版本信息、数据边界与技术说明',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutGuomuPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: context.hgMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.hgSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return HgInkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor ?? context.hgOnSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.hgMuted,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon, {this.color = const Color(0xFF343438)});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 59, color: context.hgLine);
  }
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final choices = [
      (ThemeMode.system, Icons.brightness_auto_rounded, '跟随系统', '跟随设备的浅色与深色设置'),
      (ThemeMode.light, Icons.light_mode_rounded, '浅色', '明亮、轻盈的日间阅读体验'),
      (ThemeMode.dark, Icons.dark_mode_rounded, '深色', '低亮度环境下更舒适的观看体验'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 9, 20, 18),
          children: [
            Text(
              '显示模式',
              style: TextStyle(
                color: context.hgOnSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '选择适合当前环境的界面外观',
              style: TextStyle(color: context.hgMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 15),
            for (final choice in choices) ...[
              Material(
                color: context.hgSurfaceMuted,
                borderRadius: BorderRadius.circular(14),
                child: HgInkWell(
                  onTap: () async {
                    await controller.setMode(choice.$1);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(choice.$2, size: 21, color: context.hgOnSurface),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                choice.$3,
                                style: TextStyle(
                                  color: context.hgOnSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                choice.$4,
                                style: TextStyle(
                                  color: context.hgMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (controller.mode == choice.$1)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: HgColors.orange,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (choice != choices.last) const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }
}

class HgReleaseNotesSheet extends StatelessWidget {
  const HgReleaseNotesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: HgColors.ink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '果幕 ${HgAppMetadata.versionLabel}',
                          style: TextStyle(
                            color: context.hgOnSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          HgAppMetadata.releaseTitle,
                          style: TextStyle(
                            color: context.hgMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                itemCount: HgAppMetadata.releaseNotes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 11),
                itemBuilder: (context, index) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: const BoxDecoration(
                        color: HgColors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        HgAppMetadata.releaseNotes[index],
                        style: TextStyle(
                          color: context.hgOnSurface.withValues(alpha: 0.72),
                          fontSize: 12.5,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: () => Navigator.maybePop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: HgColors.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('知道了'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HgSourceEditorSheet extends StatefulWidget {
  const HgSourceEditorSheet({super.key, this.recovery = false});

  final bool recovery;

  @override
  State<HgSourceEditorSheet> createState() => _SourceEditorSheetState();
}

class _SourceEditorSheetState extends State<HgSourceEditorSheet> {
  late final TextEditingController _controller;
  bool _adding = false;
  bool _refreshing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _adding) return;
    setState(() {
      _adding = true;
      _message = null;
    });
    try {
      final sourceController = context.read<SourceController>();
      final normalized = await sourceController.addSource(value);
      if (!mounted) return;
      context.read<HgApi>().setBaseUrl(normalized);
      _controller.clear();
      setState(() => _message = '已添加，点击地址即可切换');
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = cleanError(error));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _message = null;
    });
    try {
      final sourceController = context.read<SourceController>();
      await sourceController.startAutoDiscovery();
      if (!mounted) return;
      setState(() => _message = '已同步 ${sourceController.sources.length} 个数据源');
    } catch (error) {
      if (mounted) setState(() => _message = cleanError(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _select(String value) async {
    final sourceController = context.read<SourceController>();
    await sourceController.selectSource(value);
    if (!mounted) return;
    context.read<HgApi>().setBaseUrl(sourceController.baseUrl);
    HgCoverRepository.instance.clear();
    await context.read<HgApi>().clearContentCache();
    if (mounted) setState(() => _message = '已切换到 ${sourceController.baseUrl}');
  }

  Future<void> _remove(String value) async {
    final sourceController = context.read<SourceController>();
    await sourceController.removeSource(value);
    if (!mounted) return;
    context.read<HgApi>().setBaseUrl(sourceController.baseUrl);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final source = context.watch<SourceController>();
    final theme = Theme.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '数据源',
                      style: TextStyle(
                        color: context.hgOnSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${source.sources.length} 个',
                    style: TextStyle(color: context.hgMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                widget.recovery
                    ? '当前地址都无法连接。请手动填写一个可用地址，或重新获取官方线路。'
                    : '客户端会通过本机网络从官方发布页和 GitHub 清单同步可用线路，也可以手动添加。',
                style: TextStyle(
                  color: widget.recovery
                      ? const Color(0xFFC64F45)
                      : context.hgMuted,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(_refreshing ? '正在同步…' : '自动获取最新地址'),
              ),
              const SizedBox(height: 16),
              ...source.sources.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: item == source.baseUrl
                        ? context.hgSurfaceHigh
                        : context.hgSurfaceMuted,
                    borderRadius: BorderRadius.circular(13),
                    child: HgInkWell(
                      onTap: () => _select(item),
                      borderRadius: BorderRadius.circular(13),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
                        child: Row(
                          children: [
                            Icon(
                              item == source.baseUrl
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: item == source.baseUrl
                                  ? HgColors.orange
                                  : const Color(0xFF9A9A9E),
                              size: 19,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                item,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.hgOnSurface,
                                  fontSize: 12,
                                  fontWeight: item == source.baseUrl
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: source.sources.length <= 1
                                  ? null
                                  : () => _remove(item),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 17,
                                color: Color(0xFF9A9A9E),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: const InputDecoration(
                  hintText: '手动填写 https://example.com',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 9),
              FilledButton(
                onPressed: _adding ? null : _add,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: HgColors.ink,
                ),
                child: Text(_adding ? '添加中…' : '添加数据源'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: const TextStyle(
                    color: Color(0xFF77777C),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '暂无缓存';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
