import 'dart:async';

import 'package:flutter/material.dart';
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
import 'drama_category_page.dart';
import 'login_sheet.dart';
import 'rank_page.dart';
import 'search_page.dart';
import 'tags_page.dart';
import 'topics_page.dart';
import 'user_activity_pages.dart';
import 'video_more_page.dart';
import '../widgets/hg_pressable.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _fallbackCategories = [
    HgVideoCategory(
      id: 24,
      name: '短剧',
      route: 'ai-duanju',
      displayName: 'AI成人短剧',
      intro: '精选热播短剧，汇集独家原创、精选推荐与最新更新内容。',
    ),
    HgVideoCategory(
      id: 25,
      name: '漫剧',
      route: 'ai-manju',
      displayName: 'AI成人漫剧',
      intro: '精选漫剧与动态漫画，发现独家原创和持续更新的好作品。',
    ),
  ];

  List<HgVideoCard> _latest = const [];
  List<HgRankItem> _hotRank = const [];
  List<HgTopic> _topics = const [];
  List<HgVideoCategory> _categories = _fallbackCategories;
  HgHomeData _home = const HgHomeData();
  bool _loading = true;
  int _unreadMessages = 0;
  bool _lastLoggedIn = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMessages());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<HgApi>();
      final homeFuture = api.home();
      final newestFuture = api.feed(size: 12, sort: 'new');
      final rankFuture = api.rank('hot');
      final topicsFuture = api.topics(size: 12);
      final categoriesFuture = api.videoCategories();
      HgHomeData home = const HgHomeData();
      try {
        home = await homeFuture;
      } catch (_) {
        // 首页组件接口失败时仍保留推荐流。
      }
      HgPage<HgVideoCard>? newest;
      try {
        newest = await newestFuture;
      } catch (_) {
        // 上新接口失败时用首页组件里的最新数据兜底。
      }
      List<HgRankItem> hotRank = const [];
      try {
        hotRank = await rankFuture;
      } catch (_) {
        // 榜单失败不影响首页其他区块。
      }
      List<HgTopic> topics = const [];
      try {
        topics = (await topicsFuture).items;
      } catch (_) {
        // 专题失败不影响首页其他区块。
      }
      List<HgVideoCategory> categories;
      try {
        categories =
            (await categoriesFuture)
                .where((item) => item.isAvailable)
                .toList(growable: false)
              ..sort((a, b) {
                const order = {'ai-duanju': 0, 'ai-manju': 1};
                return (order[a.route] ?? 99).compareTo(order[b.route] ?? 99);
              });
      } catch (_) {
        categories = _fallbackCategories;
      }
      if (!mounted) return;
      setState(() {
        _home = home;
        _categories = categories.isEmpty ? _fallbackCategories : categories;
        _latest = newest == null || newest.items.isEmpty
            ? home.latest
            : newest.items;
        _hotRank = hotRank;
        _topics = topics;
      });
      unawaited(_enrichBanners(api));
      unawaited(_warmContent(api));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<HgVideoCard> _uniqueCards(List<HgVideoCard> cards) {
    final seen = <int>{};
    return cards.where((item) => item.id > 0 && seen.add(item.id)).toList();
  }

  Future<void> _warmContent(HgApi api) async {
    if (_home.banners.isEmpty && _latest.isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final covers = [
      ..._home.banners.take(5).map((item) => item.image),
      ..._home.featured.take(4).map((item) => item.cover),
    ];
    await HgCoverRepository.instance.prefetch(covers, limit: 9);
    final ids = _uniqueCards([
      ..._home.featured,
      ..._latest.take(6),
    ]).map((item) => item.id);
    await api.prefetchVideoDetails(ids, limit: 8);
  }

  Future<void> _enrichBanners(HgApi api) async {
    if (_home.banners.isEmpty) return;
    final enriched = List<HgHomeBanner>.from(_home.banners);
    final titleById = <int, String>{};
    for (final card in [..._home.featured, ..._home.latest, ..._latest]) {
      if (card.title.trim().isNotEmpty) titleById[card.id] = card.title.trim();
    }

    // 首页 banners 当前只返回 video_id，标题为空。先从推荐/上新列表补，
    // 再请求详情兜底，绝不把“精选短剧”写进正式标题。
    try {
      final recommendations = await api.homeRecommendationsPage(size: 60);
      for (final card in recommendations.items) {
        if (card.title.trim().isNotEmpty) {
          titleById[card.id] = card.title.trim();
        }
      }
    } catch (_) {
      // 推荐列表不可用时继续使用详情接口。
    }

    final total = enriched.length;
    for (var index = 0; index < total; index += 3) {
      final end = (index + 3).clamp(0, total);
      await Future.wait([
        for (var cursor = index; cursor < end; cursor++)
          () async {
            final current = enriched[cursor];
            final localTitle = current.title.trim().isNotEmpty
                ? current.title.trim()
                : titleById[current.videoId];
            if (localTitle != null && localTitle.isNotEmpty) {
              enriched[cursor] = current.copyWith(title: localTitle);
              return;
            }
            try {
              final detail = await api.video(current.videoId);
              enriched[cursor] = current.copyWith(
                title: detail.title.trim(),
                description: detail.description,
                score: detail.score,
                episodeLabel: detail.episodeLabel,
                tags: detail.tags.take(3).toList(growable: false),
              );
            } catch (_) {
              // 保留海报与简介；标题为空时由 UI 隐藏标题层。
            }
          }(),
      ]);
      if (!mounted) return;
      setState(() => _home = _home.copyWith(banners: enriched));
    }
  }

  Future<void> _openDetail(HgVideoCard video) async {
    final latestIds = _latest.map((item) => item.id).toList(growable: false);
    final ids = latestIds.contains(video.id) ? latestIds : [video.id];
    final index = ids.indexOf(video.id).clamp(0, ids.length - 1).toInt();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DramaDetailPage(
          videoId: video.id,
          preloaded: video,
          feedIds: ids,
          feedIndex: index,
        ),
      ),
    );
  }

  Future<void> _openBanner(HgHomeBanner banner) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DramaDetailPage(
          videoId: banner.videoId,
          preloaded: HgVideoCard(
            id: banner.videoId,
            title: banner.title.trim(),
            cover: banner.image,
            description: banner.description,
            score: banner.score,
          ),
        ),
      ),
    );
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (!auth.isLoggedIn) {
      if (_unreadMessages != 0) setState(() => _unreadMessages = 0);
      return;
    }
    try {
      final count = await context.read<HgApi>().unreadMessageCount();
      if (mounted) setState(() => _unreadMessages = count);
    } catch (_) {
      // 未读消息失败不影响首页内容。
    }
  }

  Future<void> _openMessages() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyMessagesPage()));
    if (mounted) await _loadMessages();
  }

  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));
  }

  void _openTags() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TagsPage()));
  }

  void _openCategory(HgVideoCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DramaCategoryPage(category: category),
      ),
    );
  }

  void _openVideoMore(HgVideoMoreKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoMorePage(
          kind: kind,
          title: kind == HgVideoMoreKind.recommend ? '更多推荐' : '全部上新',
          subtitle: kind == HgVideoMoreKind.recommend
              ? '精选站内热门短剧与漫剧'
              : '按最近上架时间持续更新',
        ),
      ),
    );
  }

  void _openHotMore() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RankPage(showBack: true)),
    );
  }

  void _openTopics() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TopicsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (_lastLoggedIn != auth.isLoggedIn) {
      _lastLoggedIn = auth.isLoggedIn;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMessages());
    }
    if (_loading && _latest.isEmpty && _home.isEmpty) {
      return const SafeArea(child: HgLoading());
    }
    if (_error != null && _latest.isEmpty && _home.isEmpty) {
      return SafeArea(
        child: HgErrorState(error: _error!, onRetry: _load),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000 ? 4 : 2;
        final horizontal = width >= 700 ? 28.0 : 16.0;
        final gap = width >= 700 ? 16.0 : 12.0;
        final effectiveWidth = width.clamp(0, 1200).toDouble();
        final contentWidth =
            (effectiveWidth - horizontal * 2 - gap * (columns - 1))
                .clamp(0, double.infinity)
                .toDouble();
        final cellWidth = contentWidth / columns;
        final cardHeight = cellWidth / 0.68;
        final featured = _home.featured.take(10).toList(growable: false);
        final latest = _latest.take(6).toList(growable: false);
        final hot = _hotRank.take(3).toList(growable: false);
        final topics = _topics.take(6).toList(growable: false);

        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: HgRefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HomeHeader(
                        onSearch: _openSearch,
                        onMessages: _openMessages,
                        unreadMessages: _unreadMessages,
                      ),
                    ),
                    if (_home.banners.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _HomeHeroCarousel(
                          banners: _home.banners,
                          onTap: _openBanner,
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: _HomeShortcuts(
                        categories: _categories,
                        onCategory: _openCategory,
                        onTags: _openTags,
                      ),
                    ),
                    if (featured.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: '精选推荐',
                          eyebrow: '为你精选',
                          actionLabel: '更多推荐',
                          onMore: () =>
                              _openVideoMore(HgVideoMoreKind.recommend),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 245,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: featured.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) => HgVideoRailCard(
                              video: featured[index],
                              width: 142,
                              onTap: () => _openDetail(featured[index]),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (latest.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: '最近上新',
                          eyebrow: '新剧上线',
                          actionLabel: '全部上新',
                          onMore: () => _openVideoMore(HgVideoMoreKind.newest),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          0,
                          horizontal,
                          8,
                        ),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: gap,
                                mainAxisSpacing: 14,
                                mainAxisExtent: cardHeight,
                              ),
                          itemCount: latest.length,
                          itemBuilder: (context, index) => HgVideoGridCard(
                            video: latest[index],
                            onTap: () => _openDetail(latest[index]),
                          ),
                        ),
                      ),
                    ],
                    if (hot.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: '热播短剧',
                          eyebrow: '正在热播',
                          actionLabel: '更多热播',
                          onMore: _openHotMore,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                        sliver: SliverList.separated(
                          itemCount: hot.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _HotRankCard(
                            item: hot[index],
                            onTap: () => _openDetail(
                              HgVideoCard(
                                id: hot[index].videoId,
                                title: hot[index].title,
                                cover: hot[index].cover,
                                score: hot[index].score,
                                episodeCount: hot[index].episodeCount,
                                isFinished: hot[index].isFinished,
                                tags: hot[index].tags,
                                createdAt: '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (topics.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: '专题推荐',
                          eyebrow: '主题合集',
                          actionLabel: '全部专题',
                          onMore: _openTopics,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 192,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: topics.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) => _TopicRailCard(
                              topic: topics[index],
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      TopicDetailPage(topic: topics[index]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 34)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onSearch,
    required this.onMessages,
    required this.unreadMessages,
  });

  final VoidCallback onSearch;
  final VoidCallback onMessages;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: HgColors.orange,
                size: 25,
              ),
              const SizedBox(width: 7),
              const Text(
                '果幕',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const Spacer(),
              Text(
                '发现好内容',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  child: HgInkWell(
                    onTap: onSearch,
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      height: 46,
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.38,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '搜索短剧、演员或题材',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.42,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _HomeMessageButton(onTap: onMessages, unread: unreadMessages),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeMessageButton extends StatelessWidget {
  const _HomeMessageButton({required this.onTap, required this.unread});

  final VoidCallback onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          child: HgInkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Center(child: _MessageGlyph()),
            ),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: -4,
            right: -4,
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
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageGlyph extends StatelessWidget {
  const _MessageGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 21,
      height: 21,
      child: CustomPaint(painter: _MessageGlyphPainter()),
    );
  }
}

class _MessageGlyphPainter extends CustomPainter {
  const _MessageGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B3B3F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 2, size.width - 3, size.height - 6),
      const Radius.circular(5),
    );
    canvas.drawRRect(rect, paint);
    final tail = Path()
      ..moveTo(7, size.height - 4)
      ..lineTo(6, size.height)
      ..lineTo(11, size.height - 4);
    canvas.drawPath(tail, paint);
    canvas.drawLine(const Offset(6, 8), Offset(size.width - 6, 8), paint);
    canvas.drawLine(const Offset(6, 12), Offset(size.width - 9, 12), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeHeroCarousel extends StatefulWidget {
  const _HomeHeroCarousel({required this.banners, required this.onTap});

  final List<HgHomeBanner> banners;
  final ValueChanged<HgHomeBanner> onTap;

  @override
  State<_HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<_HomeHeroCarousel> {
  static const _initialPage = 10000;
  late final PageController _controller;
  Timer? _timer;
  int _absolutePage = _initialPage;
  int _index = 0;

  int get _loopCount => widget.banners.length;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _initialPage,
      viewportFraction: 0.92,
    );
    if (_loopCount > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.animateToPage(
          _absolutePage + 1,
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).width < 700 ? 228.0 : 250.0;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (value) {
              setState(() {
                _absolutePage = value;
                _index = value % _loopCount;
              });
            },
            itemBuilder: (context, index) {
              final banner = widget.banners[index % _loopCount];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _HeroSlide(
                  banner: banner,
                  onTap: () => widget.onTap(banner),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: index == _index ? 18 : 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _index
                    ? HgColors.orange
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.banner, required this.onTap});

  final HgHomeBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: HgInkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            HgCoverImage(url: banner.image, title: banner.title),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                  stops: [0.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (banner.score > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: HgColors.orange,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                banner.score.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (banner.title.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      banner.title.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                  if (banner.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      banner.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (banner.episodeLabel.isNotEmpty ||
                      banner.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (banner.episodeLabel.isNotEmpty)
                          _HeroMeta(label: banner.episodeLabel),
                        ...banner.tags
                            .take(2)
                            .map((tag) => _HeroMeta(label: tag)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: HgColors.ink,
                              size: 16,
                            ),
                            SizedBox(width: 3),
                            Text(
                              '立即观看',
                              style: TextStyle(
                                color: HgColors.ink,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _HomeShortcuts extends StatelessWidget {
  const _HomeShortcuts({
    required this.categories,
    required this.onCategory,
    required this.onTags,
  });

  final List<HgVideoCategory> categories;
  final ValueChanged<HgVideoCategory> onCategory;
  final VoidCallback onTags;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
      child: Row(
        children: [
          for (var index = 0; index < categories.take(2).length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(
              child: _ShortcutCard(
                icon: _ShortcutGlyph(
                  type: categories[index].route == 'ai-duanju'
                      ? _ShortcutGlyphType.play
                      : _ShortcutGlyphType.comic,
                ),
                title: categories[index].name,
                subtitle: categories[index].route == 'ai-duanju'
                    ? '热播与原创'
                    : '动态漫剧',
                onTap: () => onCategory(categories[index]),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: _ShortcutCard(
              icon: const _ShortcutGlyph(type: _ShortcutGlyphType.tag),
              title: '题材标签',
              subtitle: '按喜好找剧',
              onTap: onTags,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: HgInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 22, height: 22, child: icon),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotRankCard extends StatelessWidget {
  const _HotRankCard({required this.item, required this.onTap});

  final HgRankItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: HgInkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${item.rank}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: item.rank <= 3
                        ? HgColors.orange
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: item.rank <= 3 ? 22 : 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 92,
                  child: HgCoverImage(url: item.cover, title: item.title),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.isFinished
                          ? '全 ${item.episodeCount} 集'
                          : '更新至 ${item.episodeCount} 集',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.42,
                        ),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: HgColors.orange,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          formatCount(item.metricValue),
                          style: const TextStyle(
                            color: Color(0xFF8A8A8E),
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.score.toStringAsFixed(1),
                          style: const TextStyle(
                            color: HgColors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicRailCard extends StatelessWidget {
  const _TopicRailCard({required this.topic, required this.onTap});

  final HgTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: HgInkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              HgCoverImage(url: topic.cover, title: topic.title),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD9000000)],
                    stops: [0.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 13,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${topic.videoCount} 部作品',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ShortcutGlyphType { play, comic, tag }

class _ShortcutGlyph extends StatelessWidget {
  const _ShortcutGlyph({required this.type});

  final _ShortcutGlyphType type;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShortcutGlyphPainter(type),
      size: const Size.square(22),
    );
  }
}

class _ShortcutGlyphPainter extends CustomPainter {
  const _ShortcutGlyphPainter(this.type);

  final _ShortcutGlyphType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HgColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    switch (type) {
      case _ShortcutGlyphType.play:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(2, 3, size.width - 4, size.height - 6),
            const Radius.circular(5),
          ),
          paint,
        );
        final play = Path()
          ..moveTo(9, 8)
          ..lineTo(15, 11)
          ..lineTo(9, 14)
          ..close();
        canvas.drawPath(play, paint);
      case _ShortcutGlyphType.comic:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1.5, 5, 13, 14),
            const Radius.circular(3),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(7, 2.5, 13, 14),
            const Radius.circular(3),
          ),
          paint,
        );
      case _ShortcutGlyphType.tag:
        final path = Path()
          ..moveTo(3, 9)
          ..lineTo(9, 3)
          ..lineTo(19, 3)
          ..lineTo(19, 13)
          ..lineTo(13, 19)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawCircle(const Offset(14.5, 7.5), 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShortcutGlyphPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.eyebrow,
    this.actionLabel,
    this.onMore,
  });

  final String title;
  final String eyebrow;
  final String? actionLabel;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 12, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (actionLabel != null)
            TextButton(
              onPressed: onMore,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const Icon(Icons.chevron_right_rounded, size: 17),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
