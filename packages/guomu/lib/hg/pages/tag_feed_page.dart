import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import 'detail_page.dart';

class TagFeedPage extends StatefulWidget {
  const TagFeedPage({super.key, required this.tag});

  final HgTag tag;

  @override
  State<TagFeedPage> createState() => _TagFeedPageState();
}

class _TagFeedPageState extends State<TagFeedPage> {
  final _scroll = ScrollController();
  List<HgVideoCard> _videos = const [];
  int _page = 1;
  int _pages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter >= 420) return;
    if (_page < _pages) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<HgApi>().videosByTag(
        widget.tag.name,
        page: 1,
        size: 24,
      );
      if (!mounted) return;
      setState(() {
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
    if (_loading || _loadingMore || _page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<HgApi>().videosByTag(
        widget.tag.name,
        page: _page + 1,
        size: 24,
      );
      if (!mounted) return;
      setState(() {
        _videos = [
          ..._videos,
          ...page.items.where(
            (item) => !_videos.any((old) => old.id == item.id),
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

  Future<void> _openDetail(int index) async {
    final video = _videos[index];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DramaDetailPage(
          videoId: video.id,
          preloaded: video,
          feedIds: _videos.map((item) => item.id).toList(growable: false),
          feedIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scroll,
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
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        widget.tag.name,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HgColors.orange.withValues(alpha: 0.16),
                      theme.colorScheme.surface,
                    ],
                  ),
                  border: Border.all(
                    color: HgColors.orange.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sell_rounded, size: 17),
                        const SizedBox(width: 6),
                        Text(
                          widget.tag.categoryName,
                          style: const TextStyle(
                            color: Color(0xFF9A6A55),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.tag.hotScore > 0) ...[
                          const Spacer(),
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFB3B3B7),
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatCount(widget.tag.hotScore),
                            style: const TextStyle(
                              color: Color(0xFF8A8A8E),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.tag.intro,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                        fontSize: 12.5,
                        height: 1.6,
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
            else if (_videos.isEmpty)
              const SliverToBoxAdapter(
                child: HgEmptyState(
                  icon: Icons.movie_filter_outlined,
                  title: '这个标签暂时没有作品',
                  message: '换一个标签或稍后再来看看',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                  child: Row(
                    children: [
                      const Text(
                        '相关短剧',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_videos.length} 部',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.38,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 260,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) => HgVideoGridCard(
                    video: _videos[index],
                    onTap: () => _openDetail(index),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: _loadingMore
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _page >= _pages ? '已经到底了' : '',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.32,
                              ),
                              fontSize: 10,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
