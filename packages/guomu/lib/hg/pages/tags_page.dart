import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import 'tag_feed_page.dart';
import '../widgets/hg_pressable.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  List<HgTagGroup> _groups = const [];
  List<String> _hotTags = const [];
  int _selectedIndex = 0;
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
      final results = await Future.wait<dynamic>([
        api.tagDirectory(),
        api.hotSearchTags(),
      ]);
      if (!mounted) return;
      final groups = (results[0] as HgTagDirectory).groups;
      final hotTags = results[1] as List<String>;
      setState(() {
        _groups = groups;
        _hotTags = hotTags;
        if (hotTags.isEmpty && groups.isNotEmpty) {
          _selectedIndex = 1;
        } else if (_selectedIndex > groups.length) {
          _selectedIndex = groups.isEmpty ? 0 : groups.length;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTag(HgTag tag) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => TagFeedPage(tag: tag)));
  }

  void _openTagName(String name) {
    _openTag(
      HgTag(
        id: 0,
        name: name,
        slug: '',
        categoryId: 0,
        categoryName: '热门标签',
        isHot: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final showingHot = _selectedIndex == 0;
    final group = showingHot || _groups.isEmpty
        ? null
        : _groups[_selectedIndex - 1];
    final tags = showingHot
        ? _hotTags
              .map(
                (name) => HgTag(
                  id: 0,
                  name: name,
                  slug: '',
                  categoryId: 0,
                  categoryName: '热门标签',
                  isHot: true,
                ),
              )
              .toList(growable: false)
        : (group?.tags ?? const <HgTag>[]);
    final tabItems = <String>['热门', ..._groups.map((item) => item.name)];

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '标签',
                            style: TextStyle(
                              color: context.hgOnSurface,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '按题材发现下一部短剧',
                            style: TextStyle(
                              color: context.hgMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_loading && tags.isNotEmpty)
                      Text(
                        '${tags.length} 个',
                        style: const TextStyle(
                          color: Color(0xFF9A9A9E),
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!_loading && tabItems.length > 1)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: tabItems.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => _TagCategoryTab(
                      label: tabItems[index],
                      selected: index == _selectedIndex,
                      onTap: () => setState(() => _selectedIndex = index),
                    ),
                  ),
                ),
              ),
            if (_loading && tags.isEmpty)
              const SliverToBoxAdapter(child: HgLoading())
            else if (_error != null && tags.isEmpty)
              SliverToBoxAdapter(
                child: HgErrorState(error: _error!, onRetry: _load),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showingHot ? '热门标签' : group?.name ?? '全部标签',
                        style: TextStyle(
                          color: context.hgOnSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        showingHot
                            ? '最近被频繁搜索和浏览的题材'
                            : group?.intro ?? '按题材分类浏览短剧',
                        style: const TextStyle(
                          color: Color(0xFF85858A),
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (tags.isEmpty)
                const SliverToBoxAdapter(
                  child: HgEmptyState(
                    icon: Icons.sell_outlined,
                    title: '这个分类暂时没有标签',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 62,
                        ),
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      return _TagTile(
                        tag: tag,
                        onTap: () =>
                            showingHot ? _openTagName(tag.name) : _openTag(tag),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagCategoryTab extends StatelessWidget {
  const _TagCategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.hgOnSurface : context.hgSurface,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? context.hgSurface : context.hgMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TagTile extends StatelessWidget {
  const _TagTile({required this.tag, required this.onTap});

  final HgTag tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.hgSurface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: HgInkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Text(
                '#',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tag.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.hgOnSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (tag.hotScore > 0)
                Text(
                  formatCount(tag.hotScore),
                  style: const TextStyle(color: Color(0xFFA0A0A4), fontSize: 9),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC1C0C2),
                  size: 17,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
