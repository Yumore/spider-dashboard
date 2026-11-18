import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../auth/app_controllers.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import '../widgets/hg_share_sheet.dart';
import '../widgets/hg_video_controller.dart';
import '../widgets/secure_cover.dart';
import 'login_sheet.dart';
import '../widgets/hg_pressable.dart';

class PostsPage extends StatefulWidget {
  const PostsPage({super.key, this.showBack = true});

  final bool showBack;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  static const _tabs = ['推荐', '黑料吃瓜', '短剧剧评'];
  late final PageController _pageController;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      body: Column(
        children: [
          Container(
            color: context.hgSurfaceLow,
            padding: EdgeInsets.fromLTRB(8, top + 4, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    if (widget.showBack) ...[
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      const SizedBox(width: 3),
                    ] else
                      const SizedBox(width: 8),
                    Text(
                      widget.showBack ? '社区' : '吃瓜',
                      style: TextStyle(
                        color: context.hgOnSurface,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 49,
                  child: Row(
                    children: List.generate(_tabs.length, (index) {
                      final selected = index == _tab;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _selectTab(index),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (selected) ...[
                                      _PostTabGlyph(index: index),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(
                                      _tabs[index],
                                      style: TextStyle(
                                        color: selected
                                            ? context.hgOnSurface
                                            : context.hgMuted,
                                        fontSize: selected ? 15.5 : 14,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: selected ? 18 : 0,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: context.hgOnSurface,
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
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _tabs.length,
              onPageChanged: (index) => setState(() => _tab = index),
              itemBuilder: (context, index) =>
                  _PostsFeedPane(key: ValueKey<int>(index), tabIndex: index),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostsFeedPane extends StatefulWidget {
  const _PostsFeedPane({super.key, required this.tabIndex});

  final int tabIndex;

  @override
  State<_PostsFeedPane> createState() => _PostsFeedPaneState();
}

class _PostsFeedPaneState extends State<_PostsFeedPane> {
  final ScrollController _scroll = ScrollController();
  List<HgPost> _items = const [];
  int _page = 1;
  int _pages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 420) _loadMore();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final api = context.read<HgApi>();
      final nextPage = reset ? 1 : _page + 1;
      final page = switch (widget.tabIndex) {
        1 => await api.postsByCategory(
          'remen-chigua',
          page: nextPage,
          size: 24,
        ),
        2 => await api.postsByTag('黄果原创', page: nextPage, size: 24),
        _ => await api.posts(page: nextPage, size: 24),
      };
      if (!mounted) return;
      setState(() {
        _items = reset
            ? page.items
            : [
                ..._items,
                ...page.items.where(
                  (next) => !_items.any((old) => old.id == next.id),
                ),
              ];
        _page = page.pagination.page;
        _pages = page.pagination.pages;
      });
      unawaited(_warmPostDetails(api, page.items));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _warmPostDetails(HgApi api, List<HgPost> items) async {
    final ids = items.take(4).map((item) => item.id).toList(growable: false);
    for (var index = 0; index < ids.length; index += 2) {
      await Future.wait(
        ids
            .skip(index)
            .take(2)
            .map(
              (id) => api.post(id).then<void>((_) {}, onError: (Object _) {}),
            ),
      );
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _pages) return;
    setState(() => _loadingMore = true);
    await _load(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    return HgRefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scroll,
        key: PageStorageKey<String>('posts-${widget.tabIndex}'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (_loading)
            const SliverToBoxAdapter(
              child: HgLoading(variant: HgLoadingVariant.list),
            )
          else if (_error != null)
            SliverToBoxAdapter(
              child: HgErrorState(
                error: _error!,
                onRetry: () => _load(reset: true),
              ),
            )
          else if (_items.isEmpty)
            SliverToBoxAdapter(
              child: HgEmptyState(
                icon: Icons.article_outlined,
                title: widget.tabIndex == 2 ? '暂时没有剧评' : '暂时没有内容',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              sliver: SliverList.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final post = _items[index];
                  return _PostFeedCard(
                    post: post,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PostDetailPage(postId: post.id),
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
                      padding: EdgeInsets.all(18),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const SizedBox(height: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostTabGlyph extends StatelessWidget {
  const _PostTabGlyph({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(12, 12),
      painter: _PostTabGlyphPainter(index),
    );
  }
}

class _PostTabGlyphPainter extends CustomPainter {
  const _PostTabGlyphPainter(this.index);

  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HgColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (index) {
      case 1:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, size.width - 2, size.height - 4),
            const Radius.circular(3),
          ),
          paint,
        );
        final tail = Path()
          ..moveTo(4, size.height - 3)
          ..lineTo(3, size.height)
          ..lineTo(7, size.height - 3);
        canvas.drawPath(tail, paint);
        break;
      case 2:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(2, 1, size.width - 4, size.height - 2),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.drawLine(const Offset(4, 4), const Offset(8, 4), paint);
        canvas.drawLine(const Offset(4, 7), const Offset(8, 7), paint);
        break;
      default:
        final flame = Path()
          ..moveTo(6, 11)
          ..cubicTo(1, 8, 4, 5, 5, 1)
          ..cubicTo(7, 4, 11, 6, 6, 11)
          ..close();
        canvas.drawPath(flame, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PostTabGlyphPainter oldDelegate) {
    return oldDelegate.index != index;
  }
}

class _PostFeedCard extends StatelessWidget {
  const _PostFeedCard({required this.post, required this.onTap});

  final HgPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.hgSurface,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: HgInkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 124,
                  height: 88,
                  child: HgCoverImage(url: post.cover, title: post.title),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.hgOnSurface,
                          fontSize: 14,
                          height: 1.38,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (post.tags.isNotEmpty)
                            Flexible(
                              child: Text(
                                post.tags.first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF9A6A55),
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          const Spacer(),
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 13,
                            color: Color(0xFFFF8B5A),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            formatCount(post.hot),
                            style: const TextStyle(
                              color: Color(0xFF929297),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final int postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  HgPostDetail? _detail;
  HgPostAdjacent? _adjacent;
  List<HgPost> _related = const [];
  List<String> _videoUrls = const [];
  bool _loading = true;
  Object? _error;
  bool _liked = false;
  bool _collected = false;
  int _likeCount = 0;
  int _collectCount = 0;

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
      final detail = await api.post(widget.postId);
      final adjacent = await api.postAdjacent(widget.postId);
      final related = await api.postRelated(widget.postId);
      var videos = const <String>[];
      if (detail.content.contains('post-video-player') ||
          detail.videoUrl.isNotEmpty) {
        try {
          final playback = await api.postPlayback(widget.postId);
          videos = [
            if (detail.videoUrl.isNotEmpty) detail.videoUrl,
            ...playback.videoUrls,
          ];
        } catch (_) {
          // 播放资源失败时正文仍可阅读。
        }
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _adjacent = adjacent;
        _related = related.items;
        _videoUrls = videos;
        _liked = detail.isLiked;
        _collected = detail.isCollected;
        _likeCount = detail.likeCount;
        _collectCount = detail.collectCount;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    HapticFeedback.lightImpact();
    final next = !_liked;
    setState(() {
      _liked = next;
      _likeCount = math.max(0, _likeCount + (next ? 1 : -1));
    });
    try {
      await context.read<HgApi>().likePost(widget.postId, next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _liked = !next;
        _likeCount = math.max(0, _likeCount + (next ? -1 : 1));
      });
      showHgSnack(context, cleanError(error));
    }
  }

  Future<void> _toggleCollect() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    HapticFeedback.mediumImpact();
    final next = !_collected;
    setState(() {
      _collected = next;
      _collectCount = math.max(0, _collectCount + (next ? 1 : -1));
    });
    try {
      await context.read<HgApi>().collectPost(widget.postId, next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _collected = !next;
        _collectCount = math.max(0, _collectCount + (next ? -1 : 1));
      });
      showHgSnack(context, cleanError(error));
    }
  }

  Future<void> _share() async {
    final detail = _detail;
    if (detail == null || !mounted) return;
    final url = '${resolveHgApiBaseUrl()}/archives/${detail.post.id}/';
    await showHgShareSheet(
      context,
      title: detail.post.title,
      subtitle: detail.author?.name ?? '黄果社区',
      url: url,
    );
  }

  void _openComments() {
    final detail = _detail;
    if (detail == null) return;
    showPostCommentsSheet(
      context,
      postId: detail.post.id,
      totalComments: detail.commentCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: context.hgSurface,
      appBar: AppBar(
        backgroundColor: context.hgSurface,
        surfaceTintColor: context.hgSurface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          '详情',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const HgLoading()
          : _error != null
          ? HgErrorState(error: _error!, onRetry: _load)
          : detail == null
          ? const HgEmptyState(icon: Icons.article_outlined, title: '内容不存在')
          : _ArticleBody(
              detail: detail,
              adjacent: _adjacent,
              related: _related,
              videoUrls: _videoUrls,
            ),
      bottomNavigationBar: detail == null
          ? null
          : _PostActionBar(
              liked: _liked,
              collected: _collected,
              likeCount: _likeCount,
              collectCount: _collectCount,
              commentCount: detail.commentCount,
              onLike: _toggleLike,
              onCollect: _toggleCollect,
              onComments: _openComments,
              onShare: _share,
            ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({
    required this.detail,
    required this.adjacent,
    required this.related,
    required this.videoUrls,
  });

  final HgPostDetail detail;
  final HgPostAdjacent? adjacent;
  final List<HgPost> related;
  final List<String> videoUrls;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseArticleBlocks(detail.content);
    final authoredDate = detail.post.createdAt.isNotEmpty
        ? detail.post.createdAt
        : detail.post.createdAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 7, 18, 28),
      children: [
        Text(
          detail.post.title,
          style: const TextStyle(
            color: Color(0xFF1F1F21),
            fontSize: 23,
            height: 1.35,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            HgAvatar(
              name: detail.author?.name ?? '黄果用户',
              url: detail.author?.avatar ?? '',
              size: 34,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.author?.name ?? '黄果用户',
                    style: const TextStyle(
                      color: Color(0xFF4A4A4E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (authoredDate.isNotEmpty)
                    Text(
                      authoredDate,
                      style: const TextStyle(
                        color: Color(0xFF99999D),
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFFF8B5A),
              size: 15,
            ),
            const SizedBox(width: 2),
            Text(
              formatCount(detail.hot),
              style: const TextStyle(color: Color(0xFF99999D), fontSize: 11),
            ),
          ],
        ),
        if (detail.post.tags.isNotEmpty) ...[
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: detail.post.tags
                .take(8)
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.hgSurfaceMuted,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        color: Color(0xFF77777C),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 18),
        ...List.generate(blocks.length, (index) {
          final block = blocks[index];
          return switch (block) {
            _ArticleHeadingBlock() => Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 13, bottom: 9),
              child: Text(
                block.text,
                style: const TextStyle(
                  color: Color(0xFF262629),
                  fontSize: 19,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _ArticleParagraphBlock() => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                block.text,
                style: const TextStyle(
                  color: Color(0xFF3B3B3F),
                  fontSize: 15.5,
                  height: 1.9,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            _ArticleImageBlock() => Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 15),
              child: _ArticleImage(url: block.url, title: detail.post.title),
            ),
            _ArticleVideoBlock() => Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 15),
              child: _ArticleVideo(
                url: block.index < videoUrls.length
                    ? videoUrls[block.index]
                    : '',
              ),
            ),
          };
        }),
        if (detail.videoUrl.isNotEmpty && videoUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 15),
            child: _ArticleVideo(url: detail.videoUrl),
          ),
        const SizedBox(height: 8),
        if (_adjacentPosts(adjacent).isNotEmpty)
          _AdjacentPosts(posts: _adjacentPosts(adjacent)),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            '相关阅读',
            style: TextStyle(
              color: Color(0xFF202124),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...related
              .take(6)
              .map(
                (post) => _RelatedPostRow(
                  post: post,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => PostDetailPage(postId: post.id),
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  List<HgPost> _adjacentPosts(HgPostAdjacent? value) {
    if (value == null) return const [];
    return [
      if (value.previous != null) value.previous!,
      if (value.next != null) value.next!,
    ];
  }
}

class _PostActionBar extends StatelessWidget {
  const _PostActionBar({
    required this.liked,
    required this.collected,
    required this.likeCount,
    required this.collectCount,
    required this.commentCount,
    required this.onLike,
    required this.onCollect,
    required this.onComments,
    required this.onShare,
  });

  final bool liked;
  final bool collected;
  final int likeCount;
  final int collectCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onCollect;
  final VoidCallback onComments;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.hgSurface,
        border: Border(top: BorderSide(color: context.hgLine)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: context.hgSurfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HgInkWell(
                  onTap: onComments,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '说点什么…',
                      style: TextStyle(
                        color: Color(0xFF9A9A9E),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ActionIcon(
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: liked ? HgColors.orange : const Color(0xFF646469),
              label: formatCount(likeCount),
              onTap: onLike,
            ),
            _ActionIcon(
              icon: collected ? Icons.star_rounded : Icons.star_border_rounded,
              color: collected ? HgColors.gold : const Color(0xFF646469),
              label: formatCount(collectCount),
              onTap: onCollect,
            ),
            _ActionIcon(
              icon: Icons.chat_bubble_outline_rounded,
              color: const Color(0xFF646469),
              label: formatCount(commentCount),
              onTap: onComments,
            ),
            IconButton(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded, size: 21),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HgInkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Icon(
                icon,
                key: ValueKey<IconData>(icon),
                color: color,
                size: 20,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF8B8B90), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ImageViewer(url: url, title: title),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 1.22,
          child: HgCoverImage(url: url, title: title),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            HgCoverImage(url: url, title: title, fit: BoxFit.contain),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleVideo extends StatefulWidget {
  const _ArticleVideo({required this.url});

  final String url;

  @override
  State<_ArticleVideo> createState() => _ArticleVideoState();
}

class _ArticleVideoState extends State<_ArticleVideo> {
  HgVideoController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty) unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final controller = HgVideoController(
        url: widget.url,
        headers: hgMediaHeaders(),
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: widget.url.isEmpty
              ? const Center(
                  child: Text(
                    '视频暂不可用',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                )
              : _failed
              ? const Center(
                  child: Text(
                    '视频加载失败',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                )
              : _loading || _controller == null
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(_controller!.toggle()),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _controller!.buildView(),
                      AnimatedBuilder(
                        animation: _controller!,
                        builder: (context, _) {
                          if (_controller!.isPlaying) {
                            return const SizedBox.shrink();
                          }
                          return const Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(9),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 31,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _AdjacentPosts extends StatelessWidget {
  const _AdjacentPosts({required this.posts});

  final List<HgPost> posts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text(
          '继续阅读',
          style: TextStyle(
            color: Color(0xFF202124),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 11),
        ...posts.map(
          (post) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => PostDetailPage(postId: post.id),
              ),
            ),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.hgSurfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '上一篇 / 下一篇',
                    style: TextStyle(color: Color(0xFF9A9A9E), fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3A3A3E),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RelatedPostRow extends StatelessWidget {
  const _RelatedPostRow({required this.post, required this.onTap});

  final HgPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 92,
                height: 62,
                child: HgCoverImage(url: post.cover, title: post.title),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.hgOnSurface,
                      fontSize: 13,
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatCount(post.hot)} 热度',
                    style: TextStyle(color: context.hgMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPostCommentsSheet(
  BuildContext context, {
  required int postId,
  required int totalComments,
}) {
  return showHgAdaptiveSheetBuilder<void>(
    context,
    childScrollable: true,
    barrierColor: Colors.black.withValues(alpha: 0.36),
    builder: (_) =>
        _PostCommentsSheet(postId: postId, totalComments: totalComments),
  );
}

class _PostCommentsSheet extends StatefulWidget {
  const _PostCommentsSheet({required this.postId, required this.totalComments});

  final int postId;
  final int totalComments;

  @override
  State<_PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<_PostCommentsSheet> {
  final _input = TextEditingController();
  List<HgComment> _items = const [];
  int _total = 0;
  bool _loading = true;
  bool _sending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _total = widget.totalComments;
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<HgApi>().postComments(
        widget.postId,
        size: 40,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        if (page.pagination.total > 0) _total = page.pagination.total;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    setState(() => _sending = true);
    try {
      await context.read<HgApi>().sendPostComment(widget.postId, text);
      if (!mounted) return;
      _input.clear();
      FocusScope.of(context).unfocus();
      await _load();
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(HgComment comment) async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    final next = !comment.isLiked;
    _replace(
      comment.copyWith(
        isLiked: next,
        likeCount: math.max(0, comment.likeCount + (next ? 1 : -1)),
      ),
    );
    try {
      await context.read<HgApi>().likePostComment(
        widget.postId,
        comment.id,
        next,
      );
    } catch (error) {
      if (!mounted) return;
      _replace(comment);
      showHgSnack(context, cleanError(error));
    }
  }

  void _replace(HgComment comment) {
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((item) => item.id == comment.id ? comment : item)
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<AuthController>().isLoggedIn;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: context.hgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${formatCount(_total)}条评论',
                    style: TextStyle(
                      color: context.hgOnSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 29,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const HgLoading()
                  : _error != null
                  ? HgErrorState(error: _error!, onRetry: _load)
                  : _items.isEmpty
                  ? const HgEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: '还没有评论',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 14),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 17),
                      itemBuilder: (context, index) {
                        final comment = _items[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HgAvatar(
                              name: comment.nickname,
                              url: comment.avatar,
                              size: 35,
                              color: colorFromHex(comment.avatarColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.nickname,
                                    style: const TextStyle(
                                      color: Color(0xFF88888D),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    comment.text,
                                    style: TextStyle(
                                      color: context.hgOnSurface,
                                      fontSize: 14,
                                      height: 1.55,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    [
                                      comment.time,
                                      if (comment.ipRegion.isNotEmpty)
                                        comment.ipRegion,
                                    ].join(' · '),
                                    style: const TextStyle(
                                      color: Color(0xFF9B9B9F),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _toggleLike(comment),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Column(
                                  children: [
                                    Icon(
                                      comment.isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: comment.isLiked
                                          ? HgColors.orange
                                          : const Color(0xFF77777C),
                                      size: 20,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatCount(comment.likeCount),
                                      style: const TextStyle(
                                        color: Color(0xFF949499),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 7, 16, 11),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 43,
                      decoration: BoxDecoration(
                        color: context.hgSurfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _input,
                        readOnly: !enabled,
                        onTap: enabled ? null : () => showLoginSheet(context),
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: '有趣评论千千万，不如你也来一条？',
                          hintStyle: TextStyle(
                            color: Color(0xFF9B9B9F),
                            fontSize: 12.5,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  IconButton.filled(
                    onPressed: _sending
                        ? null
                        : enabled
                        ? _send
                        : () => showLoginSheet(context),
                    style: IconButton.styleFrom(
                      backgroundColor: HgColors.ink,
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

sealed class _ArticleBlock {
  const _ArticleBlock();
}

class _ArticleHeadingBlock extends _ArticleBlock {
  const _ArticleHeadingBlock(this.text);

  final String text;
}

class _ArticleParagraphBlock extends _ArticleBlock {
  const _ArticleParagraphBlock(this.text);

  final String text;
}

class _ArticleImageBlock extends _ArticleBlock {
  const _ArticleImageBlock(this.url);

  final String url;
}

class _ArticleVideoBlock extends _ArticleBlock {
  const _ArticleVideoBlock(this.index);

  final int index;
}

List<_ArticleBlock> _parseArticleBlocks(String source) {
  final fragment = html_parser.parseFragment(source);
  final blocks = <_ArticleBlock>[];
  var videoIndex = 0;

  void collect(dom.Element element) {
    final name = element.localName;
    if (name == 'img') {
      final url = element.attributes['data-src'] ?? element.attributes['src'];
      if (url != null && url.trim().isNotEmpty) {
        blocks.add(_ArticleImageBlock(_resolveArticleUrl(url)));
      }
      return;
    }
    if (name == 'video') {
      blocks.add(_ArticleVideoBlock(videoIndex++));
      return;
    }
    if (name == 'div' && element.classes.contains('post-video-player')) {
      blocks.add(_ArticleVideoBlock(videoIndex++));
      return;
    }
    if (name == 'p' ||
        name == 'h1' ||
        name == 'h2' ||
        name == 'h3' ||
        name == 'blockquote') {
      final text = element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) {
        if (name == 'h1' || name == 'h2' || name == 'h3') {
          blocks.add(_ArticleHeadingBlock(text));
        } else {
          blocks.add(_ArticleParagraphBlock(text));
        }
      }
      return;
    }
    final children = element.children;
    if (children.isNotEmpty) {
      for (final child in children) {
        collect(child);
      }
      return;
    }
    final text = element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty) blocks.add(_ArticleParagraphBlock(text));
  }

  for (final node in fragment.children) {
    collect(node);
  }
  return blocks;
}

String _resolveArticleUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) return trimmed;
  return Uri.parse(resolveHgApiBaseUrl()).resolve(trimmed).toString();
}
