import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import '../widgets/secure_cover.dart';
import 'short_video_page.dart';

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key});

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> {
  List<HgTopic> _items = const [];
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
      final page = await context.read<HgApi>().topics(size: 30);
      if (mounted) setState(() => _items = page.items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(HgTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TopicDetailPage(topic: topic)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(6, top + 4, 18, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 1),
                    Text(
                      '专题',
                      style: TextStyle(
                        color: context.hgOnSurface,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading && _items.isEmpty)
              const SliverToBoxAdapter(child: HgLoading())
            else if (_error != null && _items.isEmpty)
              SliverToBoxAdapter(
                child: HgErrorState(error: _error!, onRetry: _load),
              )
            else if (_items.isEmpty)
              const SliverToBoxAdapter(
                child: HgEmptyState(
                  icon: Icons.collections_bookmark_outlined,
                  title: '暂时没有专题',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: _FeaturedTopic(
                    topic: _items.first,
                    onTap: () => _open(_items.first),
                  ),
                ),
              ),
              if (_items.length > 1) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
                    child: Text(
                      '更多专题',
                      style: TextStyle(
                        color: context.hgOnSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 11,
                          mainAxisSpacing: 13,
                          mainAxisExtent: 190,
                        ),
                    itemCount: _items.length - 1,
                    itemBuilder: (context, index) {
                      final topic = _items[index + 1];
                      return _TopicTile(
                        topic: topic,
                        onTap: () => _open(topic),
                      );
                    },
                  ),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeaturedTopic extends StatelessWidget {
  const _FeaturedTopic({required this.topic, required this.onTap});

  final HgTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HgColors.ink,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 246,
          child: Stack(
            fit: StackFit.expand,
            children: [
              HgCoverImage(url: topic.cover, title: topic.title),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x12000000),
                      Color(0x16000000),
                      Color(0xE6000000),
                    ],
                    stops: [0, 0.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 17,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '专题精选',
                    style: TextStyle(
                      color: HgColors.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 19,
                right: 19,
                bottom: 19,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Text(
                          '${topic.videoCount} 部作品',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 15,
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

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, required this.onTap});

  final HgTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.hgSurface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HgCoverImage(url: topic.cover, title: topic.title),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x8A000000)],
                        stops: [0.52, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 9,
                    child: Text(
                      '${topic.videoCount} 部',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(
                topic.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HgColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopicDetailPage extends StatefulWidget {
  const TopicDetailPage({super.key, required this.topic});

  final HgTopic topic;

  @override
  State<TopicDetailPage> createState() => _TopicDetailPageState();
}

class _TopicDetailPageState extends State<TopicDetailPage> {
  final _scroll = ScrollController();
  HgTopic? _topic;
  List<HgVideoCard> _videos = const [];
  List<HgTopic> _related = const [];
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _page = 1;
  int _pages = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 520) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await context.read<HgApi>().topic(widget.topic.slug);
      if (!mounted) return;
      setState(() {
        _topic = detail.topic;
        _videos = detail.videos.items;
        _related = detail.related;
        _page = detail.videos.pagination.page;
        _pages = detail.videos.pagination.pages;
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
      final detail = await context.read<HgApi>().topic(
        widget.topic.slug,
        page: _page + 1,
        size: 20,
      );
      if (!mounted) return;
      setState(() {
        _videos.addAll(
          detail.videos.items.where(
            (next) => !_videos.any((old) => old.id == next.id),
          ),
        );
        _page = detail.videos.pagination.page;
        _pages = detail.videos.pagination.pages;
      });
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openVideo(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShortVideoPage(
          videoIds: _videos.map((item) => item.id).toList(growable: false),
          startIndex: index,
          title: _topic?.title ?? widget.topic.title,
        ),
      ),
    );
  }

  void _openTopic(HgTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TopicDetailPage(topic: topic)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topic ?? widget.topic;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 284,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HgCoverImage(url: topic.cover, title: topic.title),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x48000000),
                            Color(0x09000000),
                            Color(0xD9000000),
                          ],
                          stops: [0, 0.36, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: top + 5,
                      left: 6,
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 21,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              height: 1.14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${topic.videoCount} 部作品',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
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
            else ...[
              if (topic.intro.trim().isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '专题简介',
                          style: TextStyle(
                            color: context.hgOnSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          topic.intro,
                          style: const TextStyle(
                            color: Color(0xFF66666B),
                            fontSize: 13,
                            height: 1.75,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 25, 18, 12),
                  child: Row(
                    children: [
                      Text(
                        '专题片单',
                        style: TextStyle(
                          color: context.hgOnSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_videos.isEmpty)
                const SliverToBoxAdapter(
                  child: HgEmptyState(
                    icon: Icons.movie_outlined,
                    title: '专题里还没有作品',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 11,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                    itemCount: _videos.length,
                    itemBuilder: (context, index) => HgVideoGridCard(
                      video: _videos[index],
                      onTap: () => _openVideo(index),
                    ),
                  ),
                ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              if (_related.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 26, 18, 12),
                    child: Text(
                      '相关专题',
                      style: TextStyle(
                        color: context.hgOnSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 146,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _related.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final related = _related[index];
                        return _RelatedTopic(
                          topic: related,
                          onTap: () => _openTopic(related),
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (topic.faq.isNotEmpty)
                SliverToBoxAdapter(child: _TopicFaq(items: topic.faq)),
              const SliverToBoxAdapter(child: SizedBox(height: 34)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RelatedTopic extends StatelessWidget {
  const _RelatedTopic({required this.topic, required this.onTap});

  final HgTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: HgCoverImage(url: topic.cover, title: topic.title),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              topic.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.hgOnSurface,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicFaq extends StatelessWidget {
  const _TopicFaq({required this.items});

  final List<HgTopicFaq> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 8),
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '常见问题',
            style: TextStyle(
              color: context.hgOnSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          ...items.map(
            (item) => ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              iconColor: const Color(0xFF77777C),
              collapsedIconColor: const Color(0xFF9A9A9E),
              title: Text(
                item.question,
                style: const TextStyle(
                  color: Color(0xFF343437),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.answer,
                    style: const TextStyle(
                      color: Color(0xFF747479),
                      fontSize: 12.5,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
