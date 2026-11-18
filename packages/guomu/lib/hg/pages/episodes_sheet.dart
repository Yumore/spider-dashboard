import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/app_controllers.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/hg_components.dart';
import '../widgets/secure_cover.dart';
import 'login_sheet.dart';
import 'tag_feed_page.dart';
import '../widgets/hg_pressable.dart';

Future<int?> showEpisodesSheet(
  BuildContext context, {
  required HgVideoDetail detail,
  required int currentEpisode,
}) {
  return showHgAdaptiveSheetBuilder<int>(
    context,
    childScrollable: true,
    barrierColor: Colors.black.withValues(alpha: 0.46),
    builder: (_) =>
        _EpisodesSheet(detail: detail, currentEpisode: currentEpisode),
  );
}

class _EpisodesSheet extends StatefulWidget {
  const _EpisodesSheet({required this.detail, required this.currentEpisode});

  final HgVideoDetail detail;
  final int currentEpisode;

  @override
  State<_EpisodesSheet> createState() => _EpisodesSheetState();
}

class _EpisodesSheetState extends State<_EpisodesSheet> {
  static const int _pageSize = 30;
  late int _segment;
  late int _tab;
  bool _saving = false;

  List<HgEpisode> get _episodes {
    if (widget.detail.episodes.isNotEmpty) return widget.detail.episodes;
    final count = widget.detail.totalEpisodes > 0
        ? widget.detail.totalEpisodes
        : widget.detail.episodeCount;
    return List<HgEpisode>.generate(
      count.clamp(0, 500),
      (index) => HgEpisode(number: index + 1, title: '${index + 1}'),
      growable: false,
    );
  }

  int get _segmentCount => (_episodes.length / _pageSize).ceil().clamp(1, 99);

  @override
  void initState() {
    super.initState();
    _tab = 1;
    _segment = ((widget.currentEpisode - 1) ~/ _pageSize).clamp(
      0,
      _segmentCount - 1,
    );
  }

  Future<void> _toggleFavorite() async {
    if (_saving) return;
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final auth = context.read<AuthController>();
    try {
      await auth.toggleFavorite(widget.detail.id);
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodes = _episodes;
    final total = episodes.length;
    final width = MediaQuery.sizeOf(context).width;
    final auth = context.watch<AuthController>();
    final favorite = auth.isFavorite(widget.detail.id);
    final start = _segment * _pageSize;
    final end = (start + _pageSize).clamp(0, total);
    final pageItems = episodes.sublist(start, end);

    return Container(
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 74,
                    child: HgCoverImage(
                      url: widget.detail.cover,
                      title: widget.detail.title,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.detail.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.hgOnSurface,
                          fontSize: 18,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '第 ${widget.currentEpisode} 集 · 全 $total 集',
                        style: TextStyle(
                          color: context.hgMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _SheetTab(
                  label: '简介',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 28),
                _SheetTab(
                  label: '选集',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.hgLine),
          Expanded(
            child: _tab == 0
                ? _IntroPane(detail: widget.detail)
                : Column(
                    children: [
                      if (_segmentCount > 1)
                        SizedBox(
                          height: 54,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: _segmentCount,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 26),
                            itemBuilder: (context, index) {
                              final from = index * _pageSize + 1;
                              final to = ((index + 1) * _pageSize).clamp(
                                0,
                                total,
                              );
                              return _SegmentTab(
                                label: '$from-$to',
                                selected: _segment == index,
                                onTap: () => setState(() => _segment = index),
                              );
                            },
                          ),
                        ),
                      Expanded(
                        child: pageItems.isEmpty
                            ? const Center(child: Text('暂无可选集数'))
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  20,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: width >= 560 ? 8 : 6,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 1.23,
                                    ),
                                itemCount: pageItems.length,
                                itemBuilder: (context, index) {
                                  final episode = pageItems[index];
                                  final selected =
                                      episode.number == widget.currentEpisode;
                                  return _EpisodeCell(
                                    episode: episode.number,
                                    selected: selected,
                                    onTap: () => Navigator.of(
                                      context,
                                    ).pop(episode.number),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _toggleFavorite,
                style: FilledButton.styleFrom(
                  backgroundColor: favorite
                      ? HgColors.orange.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.2
                              : 0.09,
                        )
                      : HgColors.orange,
                  foregroundColor: favorite ? HgColors.orange : Colors.white,
                  disabledBackgroundColor: HgColors.orange.withValues(
                    alpha: 0.45,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 21,
                      ),
                label: Text(
                  favorite ? '已收藏' : '收藏',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTab extends StatelessWidget {
  const _SheetTab({
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
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? context.hgOnSurface : context.hgMuted,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
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
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
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
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? context.hgOnSurface : context.hgMuted,
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EpisodeCell extends StatelessWidget {
  const _EpisodeCell({
    required this.episode,
    required this.selected,
    required this.onTap,
  });

  final int episode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? HgColors.orange.withValues(alpha: 0.14)
          : context.hgSurfaceMuted,
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: HgInkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            '$episode',
            style: TextStyle(
              color: selected ? HgColors.orange : context.hgOnSurface,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPane extends StatelessWidget {
  const _IntroPane({required this.detail});

  final HgVideoDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        if (detail.description.trim().isNotEmpty)
          Text(
            detail.description,
            style: TextStyle(
              color: context.hgOnSurface,
              fontSize: 14,
              height: 1.75,
            ),
          ),
        if (detail.tags.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: detail.tags
                .take(10)
                .map(
                  (tag) => HgTagChip(
                    label: tag,
                    compact: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TagFeedPage(
                          tag: HgTag(
                            id: 0,
                            name: tag,
                            slug: '',
                            categoryId: 0,
                            categoryName: '题材标签',
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}
