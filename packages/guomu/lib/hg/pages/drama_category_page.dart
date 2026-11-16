import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import 'detail_page.dart';
import 'tag_feed_page.dart';

class DramaCategoryPage extends StatefulWidget {
  const DramaCategoryPage({super.key, required this.category});

  final HgVideoCategory category;

  @override
  State<DramaCategoryPage> createState() => _DramaCategoryPageState();
}

class _DramaCategoryPageState extends State<DramaCategoryPage> {
  final _scroll = ScrollController();
  List<HgVideoCard> _videos = const [];
  String _sort = 'new';
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
      final page = await context.read<HgApi>().category(
        widget.category.route,
        page: 1,
        size: 24,
        sort: _sort,
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
      final page = await context.read<HgApi>().category(
        widget.category.route,
        page: _page + 1,
        size: 24,
        sort: _sort,
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

  void _changeSort(String sort) {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    _load();
  }

  void _openDetail(int index) {
    final video = _videos[index];
    Navigator.of(context).push(
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

  void _openTag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TagFeedPage(
          tag: HgTag(
            id: 0,
            name: tag,
            slug: '',
            categoryId: widget.category.id,
            categoryName: widget.category.name,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final tags = _videos
        .expand((video) => video.tags)
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .take(10)
        .toList(growable: false);
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
                    const Expanded(
                      child: Text(
                        '分类',
                        style: TextStyle(
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
                padding: const EdgeInsets.fromLTRB(18, 19, 18, 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF252529), Color(0xFF3B2926)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.category.intro,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        HgTagChip(
                          label: '最近更新',
                          selected: _sort == 'new',
                          onTap: () => _changeSort('new'),
                        ),
                        const SizedBox(width: 8),
                        HgTagChip(
                          label: '当前最热',
                          selected: _sort == 'popular',
                          onTap: () => _changeSort('popular'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (tags.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: tags
                        .map(
                          (tag) => HgTagChip(
                            label: tag,
                            compact: true,
                            onTap: () => _openTag(tag),
                          ),
                        )
                        .toList(growable: false),
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
                  title: '这个分类暂时没有作品',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: Row(
                    children: [
                      const Text(
                        '短剧片单',
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
