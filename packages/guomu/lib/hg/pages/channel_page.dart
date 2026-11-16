import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import 'detail_page.dart';

class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key, required this.category, required this.title});

  final String category;
  final String title;

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  final _scroll = ScrollController();
  List<HgVideoCard> _items = const [];
  int _page = 1;
  int _pages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  String _sort = '';

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
    if (_scroll.position.extentAfter < 450) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _page = 1;
      _error = null;
    });
    try {
      final result = await context.read<HgApi>().category(
        widget.category,
        page: 1,
        size: 24,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _items = _sorted(result.items);
        _pages = result.pagination.pages;
        _page = result.pagination.page;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final result = await context.read<HgApi>().category(
        widget.category,
        page: _page + 1,
        size: 24,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _items = [
          ..._items,
          ...result.items.where(
            (item) => !_items.any((old) => old.id == item.id),
          ),
        ];
        _page = result.pagination.page;
        _pages = result.pagination.pages;
      });
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<HgVideoCard> _sorted(List<HgVideoCard> items) {
    final copy = [...items];
    switch (_sort) {
      case 'hot':
        copy.sort((a, b) => b.hot.compareTo(a.hot));
      case 'score':
        copy.sort((a, b) => b.score.compareTo(a.score));
      case 'latest':
        copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return copy;
  }

  Future<void> _changeSort(String sort) async {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);
    return Scaffold(
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, top + 6, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '黄果片单 · 下拉刷新',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.43,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    _SortChip(
                      label: '最新更新',
                      value: '',
                      selected: _sort,
                      onTap: _changeSort,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: '当前热播',
                      value: 'hot',
                      selected: _sort,
                      onTap: _changeSort,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: '高分优先',
                      value: 'score',
                      selected: _sort,
                      onTap: _changeSort,
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
                  icon: Icons.movie_filter_outlined,
                  title: '这个频道暂时没有内容',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    crossAxisSpacing: 11,
                    mainAxisSpacing: 11,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final video = _items[index];
                    return HgVideoGridCard(
                      video: video,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DramaDetailPage(
                            videoId: video.id,
                            preloaded: video,
                            feedIds: _items
                                .map((item) => item.id)
                                .toList(growable: false),
                            feedIndex: index,
                          ),
                        ),
                      ),
                    );
                  }, childCount: _items.length),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 80,
                child: Center(
                  child: _loadingMore
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _page >= _pages && _items.isNotEmpty
                      ? Text(
                          '已经到底了',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.35,
                            ),
                            fontSize: 11,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(value),
      selectedColor: HgColors.orange,
      labelStyle: TextStyle(
        color: active ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      showCheckmark: false,
    );
  }
}
