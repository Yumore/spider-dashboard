import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import 'detail_page.dart';

/// 剧场只保留内容和切换，支持点击与左右滑动切换三个 Tab。
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  static const _tabs = ['全部', '短剧', '漫剧'];

  late final PageController _pageController;
  final Map<int, List<HgVideoCard>> _cache = {};
  final Set<int> _loadingTabs = {};
  final Map<int, Object?> _errors = {};
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    unawaited(_loadTab(0));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTab(int tabIndex, {bool force = false}) async {
    if (!force &&
        (_cache.containsKey(tabIndex) || _loadingTabs.contains(tabIndex))) {
      return;
    }
    setState(() {
      _loadingTabs.add(tabIndex);
      _errors.remove(tabIndex);
    });
    try {
      final api = context.read<HgApi>();
      final page = switch (tabIndex) {
        1 => await api.category('ai-duanju', size: 30, sort: 'new'),
        2 => await api.category('ai-manju', size: 30, sort: 'new'),
        _ => await api.feed(size: 30),
      };
      if (mounted) setState(() => _cache[tabIndex] = page.items);
    } catch (error) {
      if (mounted) setState(() => _errors[tabIndex] = error);
    } finally {
      if (mounted) setState(() => _loadingTabs.remove(tabIndex));
    }
  }

  void _selectTab(int index) {
    if (index == _tabIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _openDetail(HgVideoCard video, List<HgVideoCard> videos) {
    final ids = videos.map((item) => item.id).toList(growable: false);
    final index = ids.indexOf(video.id).clamp(0, ids.length - 1).toInt();
    Navigator.of(context).push(
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

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: context.hgSurfaceLow,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 8),
            child: _TheaterTabs(
              tabs: _tabs,
              index: _tabIndex,
              onSelected: _selectTab,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _tabs.length,
              onPageChanged: (index) {
                setState(() => _tabIndex = index);
                if (!_cache.containsKey(index) &&
                    !_loadingTabs.contains(index)) {
                  unawaited(_loadTab(index));
                }
              },
              itemBuilder: (context, index) => _buildTab(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int tabIndex) {
    final videos = _cache[tabIndex] ?? const <HgVideoCard>[];
    final loading = _loadingTabs.contains(tabIndex);
    final error = _errors[tabIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontal = width >= 700 ? 30.0 : 16.0;
        final columns = width >= 1000 ? 4 : 2;
        final gap = width >= 700 ? 16.0 : 12.0;
        final effectiveWidth = width.clamp(0, 1200).toDouble();
        final cellWidth =
            (effectiveWidth - horizontal * 2 - gap * (columns - 1)) / columns;
        final cardHeight = cellWidth / 0.68;
        return HgRefreshIndicator(
          onRefresh: () => _loadTab(tabIndex, force: true),
          child: CustomScrollView(
            key: PageStorageKey<String>('theater-$tabIndex'),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              if (loading && videos.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: HgLoading(),
                )
              else if (error != null && videos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: HgErrorState(
                    error: error,
                    onRetry: () => _loadTab(tabIndex, force: true),
                  ),
                )
              else if (videos.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: HgEmptyState(
                    icon: Icons.movie_outlined,
                    title: '还没有可播放的短剧',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 30),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: gap,
                      mainAxisSpacing: 16,
                      mainAxisExtent: cardHeight,
                    ),
                    itemCount: videos.length,
                    itemBuilder: (context, index) => HgVideoGridCard(
                      video: videos[index],
                      onTap: () => _openDetail(videos[index], videos),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TheaterTabs extends StatelessWidget {
  const _TheaterTabs({
    required this.tabs,
    required this.index,
    required this.onSelected,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final onSurface = context.hgOnSurface;
    return Row(
      children: List.generate(tabs.length, (itemIndex) {
        final selected = itemIndex == index;
        return Expanded(
          child: Semantics(
            selected: selected,
            button: true,
            label: tabs[itemIndex],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(itemIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: selected
                            ? onSurface
                            : onSurface.withValues(alpha: 0.35),
                        fontSize: selected ? 18 : 15,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: selected ? -0.35 : -0.1,
                      ),
                      child: Text(tabs[itemIndex]),
                    ),
                    const SizedBox(height: 7),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: selected ? 22 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: onSurface,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
