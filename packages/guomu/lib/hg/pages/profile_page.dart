import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../auth/app_controllers.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../utils/hg_local_history.dart';
import '../widgets/hg_components.dart';
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
                  onCollections: () => _openTab(0),
                  onHistory: () => _openTab(1),
                  onLikes: () => _openTab(2),
                ),
              )
            else
              SliverToBoxAdapter(
                child: _GuestBenefits(onLogin: () => showLoginSheet(context)),
              ),
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
          message: '看过的短剧会自动同步到这里。',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 16,
          childAspectRatio: 0.59,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _LibraryCard(
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
                    icon: Icons.mail_outline_rounded,
                    badge: messageCount,
                    onTap: onMessage,
                  ),
                  const SizedBox(width: 6),
                ],
                _HeaderIcon(icon: Icons.settings_outlined, onTap: onSettings),
              ],
            ),
          ),
          if (user == null)
            _GuestProfile(onLogin: onAccountAction)
          else ...[
            Row(
              children: [
                GestureDetector(
                  onTap: onAccountAction,
                  child: HgAvatar(
                    name: user!.nickname,
                    url: user!.avatar,
                    size: 72,
                    color: colorFromHex(user!.avatarColor),
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
  const _HeaderIcon({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: context.hgSurface.withValues(alpha: 0.72),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: context.hgOnSurface, size: 21),
            ),
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
              decoration: const BoxDecoration(shape: BoxShape.circle),
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
        FilledButton(
          onPressed: onLogin,
          style: FilledButton.styleFrom(
            backgroundColor: HgColors.ink,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('登录'),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCollections,
    required this.onHistory,
    required this.onLikes,
  });

  final VoidCallback onCollections;
  final VoidCallback onHistory;
  final VoidCallback onLikes;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.star_rounded, '追剧', context.hgOnSurface, onCollections, 0),
      (Icons.history_rounded, '历史', context.hgOnSurface, onHistory, 0),
      (Icons.favorite_rounded, '喜欢', context.hgOnSurface, onLikes, 0),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: actions
            .map(
              (action) => Expanded(
                child: InkWell(
                  onTap: action.$4,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(action.$1, color: action.$3, size: 24),
                          if (action.$5 > 0)
                            Positioned(
                              top: -5,
                              right: -9,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 15),
                                height: 15,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  action.$5 > 99 ? '99+' : '${action.$5}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        action.$2,
                        style: TextStyle(
                          color: context.hgOnSurface,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _GuestBenefits extends StatelessWidget {
  const _GuestBenefits({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '登录后同步观看记录',
            style: TextStyle(
              color: context.hgOnSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '换设备也能接着上次看到的一集继续播放',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.hgMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton(
              onPressed: onLogin,
              style: FilledButton.styleFrom(
                backgroundColor: HgColors.ink,
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Text('登录黄果账号'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.item, required this.onTap});

  final HgPlaylistItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final episodeText = item.lastEpisode > 0
        ? (item.totalEpisodes > 0
              ? '看到 ${item.lastEpisode}/${item.totalEpisodes} 集'
              : '看到 ${item.lastEpisode} 集')
        : (item.totalEpisodes > 0 ? '全 ${item.totalEpisodes} 集' : '继续观看');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
                backgroundColor: const Color(0xFFEDECE9),
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
              const SliverToBoxAdapter(
                child: HgEmptyState(
                  icon: Icons.movie_outlined,
                  title: '暂时没有内容',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.59,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _LibraryCard(
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
