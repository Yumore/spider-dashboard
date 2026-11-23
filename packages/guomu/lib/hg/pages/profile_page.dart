import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../auth/app_controllers.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../utils/hg_local_history.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_pressable.dart';
import '../widgets/hg_refresh_indicator.dart';
import '../widgets/secure_cover.dart';
import 'account_sheet.dart';
import 'login_sheet.dart';
import 'settings_page.dart';
import 'short_video_page.dart';
import 'user_activity_pages.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _tab = 0;
  bool _loading = true;
  Object? _error;
  final Map<int, List<HgPlaylistItem>> _cache = {};
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
      _loadUnreadMessages();
    });
  }

  Future<void> _load({bool force = false}) async {
    final auth = context.read<AuthController>();
    if (_tab != 1 && !auth.isLoggedIn) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    if (!force && _cache.containsKey(_tab)) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<HgApi>();
      final page = switch (_tab) {
        0 => await api.myCollects(size: 30),
        1 => HgPage<HgPlaylistItem>(
          items: await HgLocalHistory.load(),
          pagination: const HgPagination(page: 1, pages: 1, size: 30, total: 1),
        ),
        _ => await api.myLikes(size: 30),
      };
      final items = _tab == 1
          ? page.items
          : await _mergeLocalProgress(page.items);
      if (!mounted) return;
      setState(() => _cache[_tab] = items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<HgPlaylistItem>> _mergeLocalProgress(
    List<HgPlaylistItem> items,
  ) async {
    final local = {
      for (final item in await HgLocalHistory.load()) item.dramaId: item,
    };
    return items
        .map((item) {
          final progress = local[item.dramaId];
          if (progress == null) return item;
          return HgPlaylistItem(
            id: item.id,
            videoId: item.videoId ?? progress.dramaId,
            title: progress.title.isNotEmpty ? progress.title : item.title,
            cover: progress.cover.isNotEmpty ? progress.cover : item.cover,
            lastEpisode: progress.lastEpisode,
            totalEpisodes: progress.totalEpisodes > 0
                ? progress.totalEpisodes
                : item.totalEpisodes,
            positionMs: progress.positionMs,
            durationMs: progress.durationMs,
            updatedAt: progress.updatedAt,
          );
        })
        .toList(growable: false);
  }

  Future<void> _loadUnreadMessages() async {
    if (!context.read<AuthController>().isLoggedIn) {
      if (mounted && _unreadMessages != 0) {
        setState(() => _unreadMessages = 0);
      }
      return;
    }
    try {
      final count = await context.read<HgApi>().unreadMessageCount();
      if (mounted) setState(() => _unreadMessages = count);
    } catch (_) {
      // 未读角标失败不影响个人中心主体。
    }
  }

  Future<void> _selectTab(int index) async {
    if (_tab == index) return;
    setState(() {
      _tab = index;
      _loading = true;
      _error = null;
    });
    await _load();
  }

  Future<void> _openFollows() async {
    final auth = context.read<AuthController>();
    if (!auth.isLoggedIn) {
      final loggedIn = await ensureLoggedIn(context);
      if (!mounted || !loggedIn) return;
    }
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyFollowsPage()));
    if (mounted) await _load(force: true);
  }

  Future<void> _openFollowers() async {
    final auth = context.read<AuthController>();
    if (!auth.isLoggedIn) {
      final loggedIn = await ensureLoggedIn(context);
      if (!mounted || !loggedIn) return;
    }
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyFollowersPage()));
  }

  Future<void> _openMessages() async {
    final auth = context.read<AuthController>();
    if (!auth.isLoggedIn) {
      final loggedIn = await ensureLoggedIn(context);
      if (!mounted || !loggedIn) return;
    }
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyMessagesPage()));
    if (mounted) await _loadUnreadMessages();
  }

  Future<void> _openAccount() async {
    await showAccountSheet(context);
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  Future<void> _openTab(int tab) async {
    final auth = context.read<AuthController>();
    if (!auth.isLoggedIn) {
      final loggedIn = await ensureLoggedIn(context);
      if (!mounted || !loggedIn) return;
    }
    await _selectTab(tab);
    await _scrollToLibrary();
  }

  Future<void> _scrollToLibrary() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final target = _libraryKey.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  final _libraryKey = GlobalKey();
  bool _lastLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (_lastLoggedIn != auth.isLoggedIn) {
      _lastLoggedIn = auth.isLoggedIn;
      _cache.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _load(force: true);
        _loadUnreadMessages();
      });
    }
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: context.hgSurfaceLow,
      child: HgRefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>([_load(force: true), _loadUnreadMessages()]);
        },
        child: CustomScrollView(
          key: PageStorageKey<String>('profile-${auth.isLoggedIn}'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                top: top,
                user: auth.isLoggedIn ? auth.user : null,
                counts: auth.counts,
                onAccountAction: auth.isLoggedIn
                    ? _openAccount
                    : () => showLoginSheet(context),
                onMessage: _openMessages,
                onSettings: _openSettings,
                onFollowing: _openFollows,
                onFollowers: _openFollowers,
                messageCount: _unreadMessages,
                isLoggedIn: auth.isLoggedIn,
              ),
            ),
            if (auth.isLoggedIn)
              SliverToBoxAdapter(
                child: _QuickActions(
                  selected: _tab,
                  onCollections: () => _openTab(0),
                  onHistory: () => _openTab(1),
                  onLikes: () => _openTab(2),
                ),
              )
            else
              SliverToBoxAdapter(child: const _GuestBenefits()),
            if (auth.isLoggedIn) ...[
              SliverToBoxAdapter(
                key: _libraryKey,
                child: const SizedBox(height: 8),
              ),
              _buildLibrary(auth),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 34)),
          ],
        ),
      ),
    );
  }

  Widget _buildLibrary(AuthController auth) {
    final items = _cache[_tab] ?? const <HgPlaylistItem>[];
    if (_loading && items.isEmpty) {
      return const SliverToBoxAdapter(child: HgLoading());
    }
    if (_error != null && items.isEmpty) {
      return SliverToBoxAdapter(
        child: HgErrorState(error: _error!, onRetry: () => _load(force: true)),
      );
    }
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: HgEmptyState(
          icon: switch (_tab) {
            0 => Icons.star_border_rounded,
            1 => Icons.history_rounded,
            _ => Icons.favorite_border_rounded,
          },
          title: switch (_tab) {
            0 => '还没有追剧',
            1 => '还没有观看记录',
            _ => '还没有点赞内容',
          },
          message: switch (_tab) {
            0 => '追剧后会显示在这里。',
            1 => '播放过的短剧会记录在这里。',
            _ => '点赞过的短剧会显示在这里。',
          },
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      sliver: SliverGrid.builder(
        key: const ValueKey('hg-profile-library-grid'),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          crossAxisSpacing: 10,
          mainAxisSpacing: 18,
          childAspectRatio: 0.59,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _LibraryCard(
          key: ValueKey('hg-profile-library-card-${items[index].dramaId}'),
          item: items[index],
          onTap: () => _openItem(items[index]),
        ),
      ),
    );
  }

  Future<void> _openItem(HgPlaylistItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShortVideoPage(
          videoIds: [item.dramaId],
          initialEpisode: item.lastEpisode > 0 ? item.lastEpisode : 1,
          initialPositionMs: item.positionMs,
          title: item.title,
        ),
      ),
    );
    if (mounted) await _load(force: true);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.top,
    required this.user,
    required this.counts,
    required this.onAccountAction,
    required this.onMessage,
    required this.onSettings,
    required this.onFollowing,
    required this.onFollowers,
    required this.messageCount,
    required this.isLoggedIn,
  });

  final double top;
  final HgUser? user;
  final Map<String, int> counts;
  final VoidCallback onAccountAction;
  final VoidCallback onMessage;
  final VoidCallback onSettings;
  final VoidCallback onFollowing;
  final VoidCallback onFollowers;
  final int messageCount;
  final bool isLoggedIn;

  String _count(String key) {
    final value = counts[key];
    return value == null ? '-' : formatCount(value);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(18, top + 5, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF171719), Color(0xFF111112), Color(0xFF0B0B0C)]
              : const [Color(0xFFFFFDF9), Color(0xFFF5F2ED), Color(0xFFF7F7F8)],
          stops: const [0, 0.58, 1],
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: Row(
              children: [
                const Spacer(),
                if (isLoggedIn) ...[
                  _HeaderIcon(
                    key: const ValueKey('hg-profile-messages'),
                    icon: Icons.mail_outline_rounded,
                    badge: messageCount,
                    onTap: onMessage,
                    semanticLabel: '消息',
                  ),
                  const SizedBox(width: 6),
                ],
                _HeaderIcon(
                  key: const ValueKey('hg-profile-settings'),
                  icon: Icons.settings_outlined,
                  onTap: onSettings,
                  semanticLabel: '设置',
                ),
              ],
            ),
          ),
          if (user == null)
            _GuestProfile(onLogin: onAccountAction)
          else ...[
            Row(
              children: [
                HgPressable(
                  key: const ValueKey('hg-profile-avatar'),
                  haptic: true,
                  semanticLabel: '${user!.nickname}，编辑资料',
                  borderRadius: BorderRadius.circular(36),
                  pressedOpacity: 0.82,
                  onTap: onAccountAction,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.hgLine.withValues(alpha: 0.7),
                          ),
                        ),
                        child: HgAvatar(
                          name: user!.nickname,
                          url: user!.avatar,
                          size: 66,
                          color: colorFromHex(user!.avatarColor),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 23,
                          height: 23,
                          decoration: BoxDecoration(
                            color: HgColors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.hgSurface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user!.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.hgOnSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'ID：${user!.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.hgMuted, fontSize: 12),
                      ),
                      if (user!.sign.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          user!.sign,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.hgMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _ProfileStat(
                  value: _count('following'),
                  label: '关注',
                  onTap: onFollowing,
                ),
                _ProfileStat(
                  value: _count('follower') == '-'
                      ? _count('followers')
                      : _count('follower'),
                  label: '粉丝',
                  onTap: onFollowers,
                ),
                _ProfileStat(
                  value: _count('like_author') == '-'
                      ? _count('like')
                      : _count('like_author'),
                  label: '获赞',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        HgPressable(
          haptic: true,
          semanticLabel: semanticLabel,
          borderRadius: BorderRadius.circular(19),
          pressedOpacity: 0.76,
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.hgSurface.withValues(alpha: 0.72),
              shape: BoxShape.circle,
              border: Border.all(color: context.hgLine.withValues(alpha: 0.55)),
            ),
            child: Icon(icon, color: context.hgOnSurface, size: 21),
          ),
        ),
        if (badge > 0)
          Positioned(
            top: -2,
            right: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17),
              height: 17,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: HgColors.orange,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: context.hgSurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: Color(0xFF8A8A8F),
            size: 34,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '登录黄果账号',
                style: TextStyle(
                  color: context.hgOnSurface,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '同步追剧、历史和点赞记录',
                style: TextStyle(color: context.hgMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        HgPressable(
          key: const ValueKey('hg-profile-login'),
          haptic: true,
          semanticLabel: '登录黄果账号',
          borderRadius: BorderRadius.circular(12),
          pressedOpacity: 0.82,
          onTap: onLogin,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HgColors.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '登录',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HgPressable(
      onTap: onTap,
      haptic: onTap != null,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(12),
      pressedOpacity: 0.72,
      child: SizedBox(
        width: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: context.hgOnSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(color: context.hgMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.selected,
    required this.onCollections,
    required this.onHistory,
    required this.onLikes,
  });

  final int selected;
  final VoidCallback onCollections;
  final VoidCallback onHistory;
  final VoidCallback onLikes;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.star_rounded, '追剧', onCollections),
      (Icons.history_rounded, '历史', onHistory),
      (Icons.favorite_rounded, '喜欢', onLikes),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(actions.length, (index) {
          final action = actions[index];
          final active = selected == index;
          return Expanded(
            child: Semantics(
              selected: active,
              child: HgPressable(
                haptic: true,
                semanticLabel: action.$2,
                onTap: action.$3,
                pressedOpacity: 0.68,
                child: Column(
                  children: [
                    Icon(
                      action.$1,
                      color: active ? HgColors.orange : context.hgMuted,
                      size: 24,
                    ),
                    const SizedBox(height: 7),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: active ? context.hgOnSurface : context.hgMuted,
                        fontSize: 11.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                      child: Text(action.$2),
                    ),
                    const SizedBox(height: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: active ? 14 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: HgColors.orange,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _GuestBenefits extends StatelessWidget {
  const _GuestBenefits();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '登录后可用',
                style: TextStyle(
                  color: context.hgOnSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '跨设备同步',
                style: TextStyle(
                  color: context.hgMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _GuestBenefitRow(
            icon: Icons.devices_rounded,
            title: '多设备续播',
            detail: '换机后从上次看到的位置继续',
          ),
          const SizedBox(height: 13),
          const _GuestBenefitRow(
            icon: Icons.star_outline_rounded,
            title: '追剧与收藏同步',
            detail: '追剧列表、收藏内容跟随账号保存',
          ),
          const SizedBox(height: 13),
          const _GuestBenefitRow(
            icon: Icons.favorite_border_rounded,
            title: '点赞与消息同步',
            detail: '喜欢记录和互动消息不丢掉',
          ),
        ],
      ),
    );
  }
}

class _GuestBenefitRow extends StatelessWidget {
  const _GuestBenefitRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: HgColors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: HgColors.orange, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.hgOnSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.hgMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({super.key, required this.item, required this.onTap});

  final HgPlaylistItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final episodeText = item.lastEpisode > 0
        ? (item.totalEpisodes > 0
              ? '看到 ${item.lastEpisode}/${item.totalEpisodes} 集'
              : '看到 ${item.lastEpisode} 集')
        : (item.totalEpisodes > 0 ? '全 ${item.totalEpisodes} 集' : '继续观看');
    return HgPressable(
      haptic: true,
      semanticLabel: '${item.title}，$episodeText',
      borderRadius: BorderRadius.circular(14),
      pressedOpacity: 0.78,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HgCoverImage(url: item.cover, title: item.title),
                  const Positioned(
                    right: 6,
                    bottom: 6,
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 24,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.hgOnSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  episodeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.hgMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (item.progress > 0)
                Text(
                  '${(item.progress * 100).round()}%',
                  style: TextStyle(color: context.hgMuted, fontSize: 9.5),
                ),
            ],
          ),
          if (item.progress > 0) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 2.5,
                backgroundColor: context.hgLine.withValues(alpha: 0.72),
                valueColor: const AlwaysStoppedAnimation(HgColors.orange),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MyLibraryPage extends StatelessWidget {
  const MyLibraryPage({super.key, required this.favorites});

  final bool favorites;

  @override
  Widget build(BuildContext context) {
    return _LegacyLibraryPage(favorites: favorites);
  }
}

class _LegacyLibraryPage extends StatefulWidget {
  const _LegacyLibraryPage({required this.favorites});

  final bool favorites;

  @override
  State<_LegacyLibraryPage> createState() => _LegacyLibraryPageState();
}

class _LegacyLibraryPageState extends State<_LegacyLibraryPage> {
  List<HgPlaylistItem> _items = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<HgApi>();
      final page = widget.favorites
          ? await api.myCollects(size: 30)
          : HgPage<HgPlaylistItem>(
              items: await HgLocalHistory.load(),
              pagination: const HgPagination(
                page: 1,
                pages: 1,
                size: 30,
                total: 1,
              ),
            );
      final local = {
        for (final item in await HgLocalHistory.load()) item.dramaId: item,
      };
      final items = page.items
          .map((item) {
            final progress = local[item.dramaId];
            if (progress == null) return item;
            return HgPlaylistItem(
              id: item.id,
              videoId: item.videoId ?? progress.dramaId,
              title: progress.title.isNotEmpty ? progress.title : item.title,
              cover: progress.cover.isNotEmpty ? progress.cover : item.cover,
              lastEpisode: progress.lastEpisode,
              totalEpisodes: progress.totalEpisodes > 0
                  ? progress.totalEpisodes
                  : item.totalEpisodes,
              positionMs: progress.positionMs,
              durationMs: progress.durationMs,
              updatedAt: progress.updatedAt,
            );
          })
          .toList(growable: false);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, top + 4, 18, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    Text(
                      widget.favorites ? '我的追剧' : '观看历史',
                      style: TextStyle(
                        color: context.hgOnSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(child: HgLoading())
            else if (_error != null)
              SliverToBoxAdapter(
                child: HgErrorState(error: _error!, onRetry: _load),
              )
            else if (_items.isEmpty)
              SliverToBoxAdapter(
                child: HgEmptyState(
                  icon: Icons.movie_outlined,
                  title: widget.favorites ? '还没有追剧' : '还没有观看记录',
                  message: widget.favorites ? '追剧后会显示在这里。' : '播放过的短剧会记录在这里。',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.59,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _LibraryCard(
                      key: ValueKey('hg-legacy-library-card-${item.dramaId}'),
                      item: item,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ShortVideoPage(
                              videoIds: [item.dramaId],
                              initialEpisode: item.lastEpisode > 0
                                  ? item.lastEpisode
                                  : 1,
                              initialPositionMs: item.positionMs,
                              title: item.title,
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
