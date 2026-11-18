import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../widgets/hg_components.dart';
import 'detail_page.dart';
import 'tag_feed_page.dart';
import 'tags_page.dart';
import '../widgets/hg_pressable.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _historyKey = 'guomu.search.history';

  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _suggestDebouncer = Debouncer(const Duration(milliseconds: 280));
  List<String> _history = const [];
  List<String> _hotWords = const [];
  List<String> _hotTags = const [];
  List<String> _liveSuggestions = const [];
  List<HgVideoCard> _items = const [];
  List<HgVideoCard> _recommended = const [];
  String _submitted = '';
  int _page = 1;
  int _pages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadHistory();
    _loadDiscovery();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    _suggestDebouncer.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter >= 420) return;
    if (_submitted.isNotEmpty && _page < _pages) {
      _search(keyword: _submitted, more: true);
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _history = prefs.getStringList(_historyKey) ?? const []);
  }

  Future<void> _loadDiscovery() async {
    try {
      final api = context.read<HgApi>();
      List<String> hotWords = const [];
      List<String> hotTags = const [];
      List<HgVideoCard> recommended = const [];
      await Future.wait<void>([
        api.hotSearchWords().then<void>(
          (value) => hotWords = value,
          onError: (_) {},
        ),
        api.hotSearchTags().then<void>(
          (value) => hotTags = value,
          onError: (_) {},
        ),
        api
            .homeRecommendationsPage(size: 20)
            .then<void>((value) => recommended = value.items, onError: (_) {}),
      ]);
      if (!mounted) return;
      setState(() {
        _hotWords = hotWords;
        _hotTags = hotTags;
        _recommended = recommended.take(8).toList(growable: false);
      });
    } catch (_) {
      // 热搜失败不影响手动搜索。
    }
  }

  void _openTag(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TagFeedPage(
          tag: HgTag(
            id: 0,
            name: clean,
            slug: '',
            categoryId: 0,
            categoryName: '热门题材',
          ),
        ),
      ),
    );
  }

  void _openTags() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TagsPage()));
  }

  void _scheduleSuggestions(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty) {
      if (_liveSuggestions.isNotEmpty) {
        setState(() => _liveSuggestions = const []);
      }
      return;
    }
    _suggestDebouncer.run(() async {
      try {
        final words = await context.read<HgApi>().searchSuggestions(keyword);
        if (mounted && _controller.text.trim() == keyword) {
          setState(() => _liveSuggestions = words.take(8).toList());
        }
      } catch (_) {
        // 联想词失败时保留普通搜索。
      }
    });
  }

  Future<void> _saveHistory(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    final next = [
      clean,
      ..._history.where((item) => item != clean),
    ].take(10).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, next);
    if (mounted) setState(() => _history = next);
  }

  Future<void> _search({String? keyword, bool more = false}) async {
    final text = (keyword ?? _controller.text).trim();
    if (text.isEmpty ||
        (more && (_loadingMore || _loading || _page >= _pages))) {
      return;
    }
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _focus.unfocus();
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _submitted = text;
        _page = 1;
        _pages = 1;
        _items = const [];
        _liveSuggestions = const [];
        _error = null;
      }
    });
    try {
      final result = await context.read<HgApi>().search(
        text,
        page: more ? _page + 1 : 1,
        size: 24,
      );
      if (!mounted) return;
      await _saveHistory(text);
      if (!mounted) return;
      setState(() {
        _items = more
            ? [
                ..._items,
                ...result.items.where(
                  (item) => !_items.any((old) => old.id == item.id),
                ),
              ]
            : result.items;
        _page = result.pagination.page;
        _pages = result.pagination.pages;
        _submitted = text;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final hasSearch = _submitted.isNotEmpty;
    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, top + 5, 14, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: false,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: '搜索短剧、演员或题材',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {
                                    _submitted = '';
                                    _items = const [];
                                    _liveSuggestions = const [];
                                  });
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                      onChanged: (value) {
                        setState(() {});
                        _scheduleSuggestions(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!hasSearch && _loading == false) ...[
            if (_liveSuggestions.isNotEmpty)
              SliverToBoxAdapter(
                child: _SuggestionSection(
                  words: _liveSuggestions,
                  onTap: (word) => _search(keyword: word),
                ),
              ),
            if (_history.isNotEmpty)
              SliverToBoxAdapter(
                child: _KeywordSection(
                  title: '最近搜索',
                  icon: Icons.history_rounded,
                  words: _history,
                  onTap: (word) => _search(keyword: word),
                  trailing: TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove(_historyKey);
                      if (mounted) setState(() => _history = const []);
                    },
                    child: const Text('清空'),
                  ),
                ),
              ),
            if (_hotWords.isNotEmpty)
              SliverToBoxAdapter(
                child: _KeywordSection(
                  title: '大家都在搜',
                  icon: Icons.search_rounded,
                  words: _hotWords,
                  onTap: (word) => _search(keyword: word),
                ),
              ),
            if (_hotTags.isNotEmpty)
              SliverToBoxAdapter(
                child: _KeywordSection(
                  title: '热门题材',
                  icon: Icons.local_fire_department_rounded,
                  words: _hotTags,
                  onTap: _openTag,
                  trailing: TextButton(
                    onPressed: _openTags,
                    child: const Text('全部标签'),
                  ),
                ),
              ),
            if (_recommended.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: HgColors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        '猜你喜欢',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '根据热播内容推荐',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.36,
                          ),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 230,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _recommended.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 11),
                    itemBuilder: (context, index) {
                      final video = _recommended[index];
                      return HgVideoRailCard(
                        video: video,
                        width: 134,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DramaDetailPage(
                              videoId: video.id,
                              preloaded: video,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
          if (_loading)
            const SliverToBoxAdapter(child: HgLoading())
          else if (_error != null && hasSearch)
            SliverToBoxAdapter(
              child: HgErrorState(
                error: _error!,
                onRetry: () => _search(keyword: _submitted),
              ),
            )
          else if (hasSearch) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '「$_submitted」的搜索结果',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_items.isNotEmpty)
                      Text(
                        '${_items.length} 部',
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
            ),
            if (_items.isEmpty)
              SliverToBoxAdapter(
                child: HgEmptyState(
                  icon: Icons.search_off_rounded,
                  title: '没有找到相关内容',
                  message: '换个关键词试试，或到分类剧场逛逛',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
                height: 90,
                child: Center(
                  child: _loadingMore
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _items.isEmpty ? '' : '已经到底了',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.34,
                            ),
                            fontSize: 11,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionSection extends StatelessWidget {
  const _SuggestionSection({required this.words, required this.onTap});

  final List<String> words;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: context.hgSurface,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          children: List.generate(words.length, (index) {
            final word = words[index];
            return HgInkWell(
              onTap: () => onTap(word),
              borderRadius: BorderRadius.vertical(
                top: index == 0 ? const Radius.circular(13) : Radius.zero,
                bottom: index == words.length - 1
                    ? const Radius.circular(13)
                    : Radius.zero,
              ),
              child: SizedBox(
                height: 45,
                child: Row(
                  children: [
                    const SizedBox(width: 13),
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF929297),
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF333336),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.north_west_rounded,
                      color: Color(0xFFB1B1B5),
                      size: 16,
                    ),
                    const SizedBox(width: 13),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _KeywordSection extends StatelessWidget {
  const _KeywordSection({
    required this.title,
    required this.icon,
    required this.words,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<String> words;
  final ValueChanged<String> onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: HgColors.orange, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: words
                .map(
                  (word) => ActionChip(
                    label: Text(word),
                    onPressed: () => onTap(word),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
