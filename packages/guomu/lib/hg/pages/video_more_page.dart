import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import 'detail_page.dart';

enum HgVideoMoreKind { recommend, newest }

class VideoMorePage extends StatefulWidget {
  const VideoMorePage({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  final HgVideoMoreKind kind;
  final String title;
  final String subtitle;

  @override
  State<VideoMorePage> createState() => _VideoMorePageState();
}

class _VideoMorePageState extends State<VideoMorePage> {
  final _scroll = ScrollController();
  List<HgVideoCard> _items = const [];
  int _page = 1;
  int _pages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter >= 480) return;
    _load(reset: false);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else if (_loadingMore || _loading || _page >= _pages) {
      return;
    }
    if (!reset) setState(() => _loadingMore = true);
    try {
      final api = context.read<HgApi>();
      final result = switch (widget.kind) {
        HgVideoMoreKind.recommend => await api.homeRecommendationsPage(
          page: reset ? 1 : _page + 1,
          size: 20,
        ),
        HgVideoMoreKind.newest => await api.feed(
          page: reset ? 1 : _page + 1,
          size: 24,
          sort: 'new',
        ),
      };
      if (!mounted) return;
      setState(() {
        _items = reset
            ? result.items
            : [
                ..._items,
                ...result.items.where(
                  (next) => !_items.any((old) => old.id == next.id),
                ),
              ];
        _page = result.pagination.page;
        _pages = result.pagination.pages;
      });
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

  void _openDetail(int index) {
    final video = _items[index];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DramaDetailPage(
          videoId: video.id,
          preloaded: video,
          feedIds: _items.map((item) => item.id).toList(growable: false),
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
        onRefresh: () => _load(reset: true),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.42,
                              ),
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
                child: HgErrorState(
                  error: _error!,
                  onRetry: () => _load(reset: true),
                ),
              )
            else if (_items.isEmpty)
              const SliverToBoxAdapter(
                child: HgEmptyState(
                  icon: Icons.movie_filter_outlined,
                  title: '暂时没有内容',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 15,
                    mainAxisExtent: 275,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) => HgVideoGridCard(
                    video: _items[index],
                    onTap: () => _openDetail(index),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 54,
                child: Center(
                  child: _loadingMore
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _items.isNotEmpty && _page >= _pages ? '已经到底了' : '',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.3,
                            ),
                            fontSize: 10,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
