import 'package:flutter/material.dart';
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

Future<int?> showPlayerInfoSheet(
  BuildContext context, {
  required HgVideoDetail detail,
  required List<HgEpisode> episodes,
  required int currentEpisode,
}) {
  return showHgAdaptiveSheetBuilder<int>(
    context,
    childScrollable: true,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (_) => _PlayerInfoSheet(
      detail: detail,
      episodes: episodes,
      currentEpisode: currentEpisode,
    ),
  );
}

class _PlayerInfoSheet extends StatefulWidget {
  const _PlayerInfoSheet({
    required this.detail,
    required this.episodes,
    required this.currentEpisode,
  });

  final HgVideoDetail detail;
  final List<HgEpisode> episodes;
  final int currentEpisode;

  @override
  State<_PlayerInfoSheet> createState() => _PlayerInfoSheetState();
}

class _PlayerInfoSheetState extends State<_PlayerInfoSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final favorite = auth.isFavorite(widget.detail.id);
    return Material(
      color: context.hgSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: context.hgLine,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 58,
                    height: 78,
                    child: HgCoverImage(
                      url: widget.detail.cover,
                      title: widget.detail.title,
                    ),
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
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '第 ${widget.currentEpisode} 集 · ${widget.detail.episodeLabel}',
                        style: TextStyle(
                          color: context.hgMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final loggedIn = await ensureLoggedIn(context);
                    if (!context.mounted || !loggedIn) return;
                    try {
                      await auth.toggleFavorite(widget.detail.id);
                    } catch (error) {
                      if (context.mounted) {
                        showHgSnack(context, cleanError(error));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(76, 40),
                    backgroundColor: favorite
                        ? context.hgSurfaceMuted
                        : HgColors.orange,
                    foregroundColor: favorite
                        ? context.hgOnSurface
                        : Colors.white,
                  ),
                  child: Text(favorite ? '已追剧' : '追剧'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, indent: 18, endIndent: 18),
          SizedBox(
            height: 46,
            child: Row(
              children: [
                _SheetTab(
                  label: '简介',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _SheetTab(
                  label: '选集',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 18, endIndent: 18),
          if (_tab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.detail.description.isEmpty
                        ? '暂无剧情简介'
                        : widget.detail.description,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.75,
                      color: context.hgOnSurface.withValues(alpha: 0.78),
                    ),
                  ),
                  if (widget.detail.tags.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.detail.tags
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
            )
          else
            _EpisodeGrid(
              episodes: widget.episodes,
              currentEpisode: widget.currentEpisode,
            ),
        ],
      ),
    );
  }
}

class _SheetTab extends StatelessWidget {
  const _SheetTab({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? context.hgOnSurface : context.hgMuted,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (selected)
              const Positioned(
                bottom: 0,
                child: SizedBox(
                  width: 18,
                  height: 3,
                  child: ColoredBox(color: HgColors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeGrid extends StatelessWidget {
  const _EpisodeGrid({required this.episodes, required this.currentEpisode});

  final List<HgEpisode> episodes;
  final int currentEpisode;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('暂无可选集数')),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisExtent: 46,
        crossAxisSpacing: 8,
        mainAxisSpacing: 9,
      ),
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final selected = episode.number == currentEpisode;
        return Material(
          color: selected
              ? HgColors.orange.withValues(alpha: 0.14)
              : context.hgSurfaceMuted,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(episode.number),
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(
                '${episode.number}',
                style: TextStyle(
                  color: selected ? HgColors.orange : context.hgOnSurface,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
