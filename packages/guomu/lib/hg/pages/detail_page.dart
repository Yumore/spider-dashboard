import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../auth/app_controllers.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_download_manager.dart';
import '../utils/hg_format.dart';
import '../utils/hg_local_history.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../services/hg_notification_service.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import '../widgets/hg_share_sheet.dart';
import '../widgets/secure_cover.dart';
import 'creator_page.dart';
import 'login_sheet.dart';
import 'short_video_page.dart';
import 'tag_feed_page.dart';

class DramaDetailPage extends StatefulWidget {
  const DramaDetailPage({
    super.key,
    required this.videoId,
    this.preloaded,
    this.feedIds = const [],
    this.feedIndex = 0,
  });

  final int videoId;
  final HgVideoCard? preloaded;
  final List<int> feedIds;
  final int feedIndex;

  @override
  State<DramaDetailPage> createState() => _DramaDetailPageState();
}

class _DramaDetailPageState extends State<DramaDetailPage> {
  HgVideoDetail? _detail;
  bool _loading = true;
  bool _descriptionExpanded = false;
  HgPlaylistItem? _history;
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
      final detail = await context.read<HgApi>().video(widget.videoId);
      final history = await HgLocalHistory.find(widget.videoId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _history = history;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play([int? episode]) async {
    final ids = widget.feedIds.isEmpty ? [widget.videoId] : widget.feedIds;
    final safeIndex = ids.indexOf(widget.videoId);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShortVideoPage(
          videoIds: ids,
          startIndex: safeIndex >= 0 ? safeIndex : widget.feedIndex,
          initialEpisode: episode,
          initialPositionMs: episode == null ? null : 0,
          title: _detail?.title ?? widget.preloaded?.title ?? '沉浸剧场',
        ),
      ),
    );
    if (!mounted) return;
    final history = await HgLocalHistory.find(widget.videoId);
    if (mounted) setState(() => _history = history);
  }

  Future<void> _showMoreMenu() async {
    final detail = _detail;
    final title = detail?.title ?? widget.preloaded?.title ?? '短剧';
    final episodeLabel = detail?.episodeLabel ?? '黄果短剧';
    await showHgAdaptiveSheetBuilder<void>(
      context,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: sheetContext.hgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 9),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5E7),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sheetContext.hgOnSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            episodeLabel,
                            style: const TextStyle(
                              color: Color(0xFF929297),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              _DetailAction(
                icon: Icons.ios_share_rounded,
                title: '分享短剧',
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(
                    showHgShareSheet(
                      context,
                      title: title,
                      subtitle: episodeLabel,
                      url: '${resolveHgApiBaseUrl()}/video/${widget.videoId}/',
                    ),
                  );
                },
              ),
              _DetailAction(
                icon: Icons.refresh_rounded,
                title: '刷新详情',
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_load());
                },
              ),
              _DetailAction(
                icon: Icons.download_for_offline_outlined,
                title: '缓存全集',
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_cacheAllDrama());
                },
              ),
              _DetailAction(
                icon: Icons.play_arrow_rounded,
                title: '从头播放',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _play(1);
                },
              ),
              if (_history != null)
                _DetailAction(
                  icon: Icons.history_toggle_off_rounded,
                  title: '清除本剧观看记录',
                  color: const Color(0xFFC64F45),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await HgLocalHistory.remove(widget.videoId);
                    if (mounted) {
                      setState(() => _history = null);
                      showHgSnack(context, '本剧观看记录已清除');
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cacheAllDrama() async {
    final detail = _detail;
    if (detail == null) {
      showHgSnack(context, '详情还在加载，请稍后再试');
      return;
    }
    await HgNotificationService.requestPermissions();
    if (!mounted) return;
    final manager = context.read<HgDownloadManager>();
    await manager.startDramaDownload(detail);
    if (mounted) {
      showHgSnack(context, '已加入缓存队列，可在“设置 → 我的下载”查看进度');
    }
  }

  Future<void> _toggleFavorite() async {
    if (!await ensureLoggedIn(context) || !mounted) return;
    HapticFeedback.mediumImpact();
    try {
      await context.read<AuthController>().toggleFavorite(widget.videoId);
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final fallback = widget.preloaded;
    final title = detail?.title ?? fallback?.title ?? '短剧详情';
    final cover = detail?.cover ?? fallback?.cover ?? '';
    final theme = Theme.of(context);
    final episodes = detail?.episodes ?? const <HgEpisode>[];
    final favorite = context.watch<AuthController>().isFavorite(widget.videoId);

    return Scaffold(
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _toggleFavorite,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(56, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  foregroundColor: favorite
                      ? HgColors.orange
                      : theme.colorScheme.onSurface,
                ),
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                ),
                label: Text(favorite ? '已追剧' : '追剧'),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: detail == null ? null : _cacheAllDrama,
                tooltip: '缓存全集',
                icon: const Icon(Icons.download_for_offline_outlined),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading || detail == null ? null : _play,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    detail == null
                        ? '加载中…'
                        : (_history?.lastEpisode ?? 0) > 0
                        ? '继续观看 · 第 ${_history!.lastEpisode} 集'
                        : '立即播放 · 第 1 集',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 410,
              pinned: true,
              stretch: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.32),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.32),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      onPressed: _showMoreMenu,
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    HgCoverImage(url: cover, title: title),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x44000000),
                            Colors.transparent,
                            Color(0xE6000000),
                          ],
                          stops: [0, 0.5, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 22,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 6,
                                  children: [
                                    if (fallback?.isOriginal == true ||
                                        detail?.isOriginal == true)
                                      _DetailTag(
                                        text: '独家原创',
                                        color: HgColors.gold,
                                      ),
                                    if (fallback?.isFinished == true ||
                                        detail?.isFinished == true)
                                      const _DetailTag(text: '已完结'),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    height: 1.08,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.9,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ((detail?.score ?? fallback?.score ?? 0) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    (detail?.score ?? fallback!.score)
                                        .toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading && detail == null)
              const SliverToBoxAdapter(
                child: HgLoading(variant: HgLoadingVariant.list),
              )
            else if (_error != null && detail == null)
              SliverToBoxAdapter(
                child: HgErrorState(error: _error!, onRetry: _load),
              )
            else if (detail != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 19, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: detail.author == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => CreatorPage(
                                          userId: detail.author!.id,
                                        ),
                                      ),
                                    ),
                              borderRadius: BorderRadius.circular(10),
                              child: Row(
                                children: [
                                  if (detail.author != null) ...[
                                    HgAvatar(
                                      name: detail.author!.name,
                                      url: detail.author!.avatar,
                                      size: 40,
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          detail.author?.name ?? '黄果短剧',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          detail.episodeLabel,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.44),
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _Stat(label: '热度', value: formatCount(detail.hot)),
                          const SizedBox(width: 14),
                          _Stat(
                            label: '收藏',
                            value: formatCount(detail.collectCount),
                          ),
                          const SizedBox(width: 14),
                          _Stat(
                            label: '评论',
                            value: formatCount(detail.commentCount),
                          ),
                        ],
                      ),
                      if (detail.tags.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: detail.tags
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
                              .toList(),
                        ),
                      ],
                      if (detail.description.isNotEmpty) ...[
                        const SizedBox(height: 21),
                        Row(
                          children: [
                            Text(
                              '剧情简介',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              detail.createdAt,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detail.description,
                          maxLines: _descriptionExpanded ? null : 4,
                          overflow: _descriptionExpanded
                              ? null
                              : TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.76,
                            ),
                            fontSize: 13,
                            height: 1.65,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _descriptionExpanded = !_descriptionExpanded,
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          child: Text(_descriptionExpanded ? '收起' : '展开简介'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text('选集', style: theme.textTheme.titleLarge),
                          const Spacer(),
                          Text(
                            episodes.isEmpty
                                ? '暂未返回选集'
                                : '共 ${episodes.length} 集',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.43,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (episodes.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            '选集信息为空，可直接播放第 1 集。',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 76,
                                mainAxisExtent: 48,
                                crossAxisSpacing: 9,
                                mainAxisSpacing: 9,
                              ),
                          itemCount: episodes.length,
                          itemBuilder: (context, index) {
                            final episode = episodes[index];
                            return Material(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: () => _play(episode.number),
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: Text(
                                    '${episode.number}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 80),
                    ],
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

class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.text, this.color = Colors.white});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: color == Colors.white ? 0.17 : 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color == Colors.white ? Colors.white : HgColors.ink,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? HgColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: effective, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: effective,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB1B1B5),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}
