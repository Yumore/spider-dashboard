import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../auth/app_controllers.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import '../widgets/secure_cover.dart';
import 'detail_page.dart';
import 'login_sheet.dart';

class CreatorPage extends StatefulWidget {
  const CreatorPage({super.key, required this.userId, this.preloaded});

  final int userId;
  final HgUser? preloaded;

  @override
  State<CreatorPage> createState() => _CreatorPageState();
}

class _CreatorPageState extends State<CreatorPage> {
  final _scroll = ScrollController();
  HgUser? _user;
  List<HgVideoCard> _videos = const [];
  int _page = 1;
  int _pages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _following = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _user = widget.preloaded;
    _following = widget.preloaded?.isFollowing ?? false;
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 500) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<HgApi>();
      final results = await Future.wait<dynamic>([
        api.user(widget.userId),
        api.videosByUser(widget.userId, size: 24),
      ]);
      if (!mounted) return;
      final user = results[0] as HgUser;
      final page = results[1] as HgPage<HgVideoCard>;
      setState(() {
        _user = user;
        _following = user.isFollowing;
        _videos = page.items;
        _page = page.pagination.page;
        _pages = page.pagination.pages;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<HgApi>().videosByUser(
        widget.userId,
        page: _page + 1,
        size: 24,
      );
      if (!mounted) return;
      setState(() {
        _videos = [
          ..._videos,
          ...page.items.where(
            (next) => !_videos.any((old) => old.id == next.id),
          ),
        ];
        _page = page.pagination.page;
        _pages = page.pagination.pages;
      });
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleFollow() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    HapticFeedback.lightImpact();
    final next = !_following;
    setState(() => _following = next);
    try {
      await context.read<HgApi>().follow(widget.userId, next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _following = !next);
      showHgSnack(context, cleanError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final auth = context.watch<AuthController>();
    final isSelf = auth.user?.id == widget.userId;
    final top = MediaQuery.paddingOf(context).top;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(16, top + 5, 16, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? const [
                            Color(0xFF14201B),
                            Color(0xFF241A15),
                            Color(0xFF111112),
                          ]
                        : const [
                            Color(0xFFF1FAF6),
                            Color(0xFFFFF6EF),
                            Color(0xFFF7F7F8),
                          ],
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 42,
                      child: Row(
                        children: [
                          Material(
                            color: Colors.white.withValues(alpha: 0.7),
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (user != null)
                      Row(
                        children: [
                          HgAvatar(
                            name: user.nickname,
                            url: user.avatar,
                            size: 76,
                            color: colorFromHex(user.avatarColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.hgOnSurface,
                                    fontSize: 22,

                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'ID：${user.id}',
                                  style: TextStyle(
                                    color: context.hgMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                                if (user.sign.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    user.sign,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF6E6E73),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isSelf)
                            FilledButton(
                              onPressed: _toggleFollow,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                backgroundColor: _following
                                    ? context.hgSurfaceMuted
                                    : context.hgOnSurface,
                                foregroundColor: _following
                                    ? context.hgMuted
                                    : context.hgSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                _following ? '已关注' : '关注',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      )
                    else
                      const SizedBox(height: 76),
                    if (user != null) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _CreatorStat(
                            value: formatCount(
                              user.counts['follower'] ??
                                  user.counts['followers'] ??
                                  0,
                            ),
                            label: '粉丝',
                          ),
                          _CreatorStat(
                            value: formatCount(user.counts['video'] ?? 0),
                            label: '作品',
                          ),
                          _CreatorStat(
                            value: formatCount(user.counts['like'] ?? 0),
                            label: '获赞',
                          ),
                        ],
                      ),
                    ],
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
            else ...[
              SliverToBoxAdapter(
                child: Container(
                  color: context.hgSurface,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.fromLTRB(16, 17, 16, 8),
                  child: Text(
                    '作品',
                    style: TextStyle(
                      color: context.hgOnSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (_videos.isEmpty)
                const SliverToBoxAdapter(
                  child: HgEmptyState(
                    icon: Icons.video_library_outlined,
                    title: '暂无公开作品',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 11,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.66,
                        ),
                    itemCount: _videos.length,
                    itemBuilder: (context, index) {
                      final video = _videos[index];
                      return HgVideoGridCard(
                        video: video,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DramaDetailPage(
                              videoId: video.id,
                              preloaded: video,
                              feedIds: _videos
                                  .map((item) => item.id)
                                  .toList(growable: false),
                              feedIndex: index,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: Center(
                  child: _loadingMore
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const SizedBox(height: 30),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreatorStat extends StatelessWidget {
  const _CreatorStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF202124),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF7C7C81), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
