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
    initialSize: MediaQuery.sizeOf(context).height < 500 ? 0.9 : 0.56,
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
  final _selectedCell = GlobalKey();
  final _selectedRange = GlobalKey();

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
    final index = _episodes.indexWhere(
      (episode) => episode.number == widget.currentEpisode,
    );
    _segment = (index < 0 ? 0 : index ~/ _pageSize).clamp(0, _segmentCount - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final key in [_selectedRange, _selectedCell]) {
        final target = key.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: 1,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
      }
    });
  }

  Future<void> _toggleFavorite() async {
    if (_saving) return;
    if (!mounted) return;
    try {
      await runAuthenticated(context, () async {
        if (!mounted) return false;
        HapticFeedback.mediumImpact();
        setState(() => _saving = true);
        await context.read<AuthController>().toggleFavorite(widget.detail.id);
        return true;
      });
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
    final favorite = context.watch<AuthController>().isFavorite(
      widget.detail.id,
    );
    final start = _segment * _pageSize;
    final end = (start + _pageSize).clamp(0, total);
    final pageItems = episodes.sublist(start, end);

    return Material(
      color: context.hgSurface,
      child: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 58,
                      child: HgCoverImage(
                        url: widget.detail.cover,
                        title: widget.detail.title,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                              fontSize: 16,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '第 ${widget.currentEpisode} 集 · ${widget.detail.episodeLabel}',
                            style: TextStyle(
                              color: context.hgMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: favorite ? '取消追剧' : '追剧',
                      onPressed: _saving ? null : _toggleFavorite,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              favorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: favorite
                                  ? HgColors.orange
                                  : context.hgOnSurface,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
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
            ),
            SliverToBoxAdapter(
              child: Divider(height: 1, color: context.hgLine),
            ),
            if (_tab == 0)
              SliverToBoxAdapter(child: _IntroPane(detail: widget.detail))
            else ...[
              if (_segmentCount > 1)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: List.generate(_segmentCount, (index) {
                        final first = index * _pageSize;
                        final last =
                            ((index + 1) * _pageSize).clamp(0, total) - 1;
                        return Padding(
                          key: index == _segment ? _selectedRange : null,
                          padding: const EdgeInsets.only(right: 22),
                          child: _SegmentTab(
                            label:
                                '${episodes[first].number}-${episodes[last].number}',
                            selected: _segment == index,
                            onTap: () => setState(() => _segment = index),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: pageItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '暂无可选集数',
                          style: TextStyle(color: context.hgMuted),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    ((constraints.maxWidth - 32) / 56)
                                        .floor()
                                        .clamp(3, 8),
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                mainAxisExtent: 48,
                              ),
                          itemCount: pageItems.length,
                          itemBuilder: (context, index) {
                            final episode = pageItems[index];
                            final selected =
                                episode.number == widget.currentEpisode;
                            return _EpisodeCell(
                              key: selected ? _selectedCell : null,
                              episode: episode.number,
                              selected: selected,
                              onTap: () =>
                                  Navigator.of(context).pop(episode.number),
                            );
                          },
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
    return HgPressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        height: 48,
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
      ),
    );
  }
}

class _EpisodeCell extends StatelessWidget {
  const _EpisodeCell({
    super.key,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
      ),
    );
  }
}
