import 'dart:async';

import 'package:flutter/material.dart';

import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import 'secure_cover.dart';
import 'hg_pressable.dart';

class HgSectionTitle extends StatelessWidget {
  const HgSectionTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? eyebrow;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: HgColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: HgColors.orange, size: 17),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.46),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class HgVideoGridCard extends StatelessWidget {
  const HgVideoGridCard({
    super.key,
    required this.video,
    required this.onTap,
    this.hero = false,
  });

  final HgVideoCard video;
  final VoidCallback onTap;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(hero ? 24 : 16);
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${video.title}，${video.episodeLabel}',
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: HgInkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HgCoverImage(
                  url: video.cover,
                  title: video.title,
                  borderRadius: radius,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x08000000),
                        Color(0xD9000000),
                      ],
                      stops: [0.42, 0.66, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: HgDramaBadges(labels: video.statusBadges),
                ),
                if (video.score > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _GlassBadge(
                      text: video.score.toStringAsFixed(1),
                      icon: Icons.star_rounded,
                    ),
                  ),
                Positioned(
                  left: 11,
                  right: 11,
                  bottom: 72,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          video.episodeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 13,
                  right: 12,
                  bottom: hero ? 16 : 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: hero ? 25 : 15.5,
                          height: 1.18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              video.author?.name ?? video.episodeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          Text(
                            formatCount(video.hot),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HgVideoMasonryCard extends StatelessWidget {
  const HgVideoMasonryCard({
    super.key,
    required this.video,
    required this.onTap,
  });

  final HgVideoCard video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final aspectRatio = 0.66 + (video.id % 3) * 0.07;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.46);
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${video.title}，${video.episodeLabel}',
        child: Material(
          color: Colors.transparent,
          child: HgInkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: aspectRatio,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        HgCoverImage(url: video.cover, title: video.title),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x9E000000)],
                              stops: [0.58, 1],
                            ),
                          ),
                        ),
                        if (video.statusBadges.isNotEmpty)
                          Positioned(
                            left: 8,
                            top: 8,
                            child: HgDramaBadges(
                              labels: video.statusBadges,
                              compact: true,
                            ),
                          ),
                        if (video.score > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: _GlassBadge(
                              text: video.score.toStringAsFixed(1),
                              icon: Icons.star_rounded,
                            ),
                          ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 9,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  video.episodeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        video.author?.name ?? '黄果短剧',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 10.5),
                      ),
                    ),
                    Icon(
                      Icons.favorite_rounded,
                      size: 12,
                      color: HgColors.orange.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatCount(video.likeCount),
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HgVideoRailCard extends StatelessWidget {
  const HgVideoRailCard({
    super.key,
    required this.video,
    required this.onTap,
    this.width = 142,
  });

  final HgVideoCard video;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.44);
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: '${video.title}，${video.episodeLabel}',
        child: Material(
          color: Colors.transparent,
          child: HgInkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 0.72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        HgCoverImage(url: video.cover, title: video.title),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xB8000000)],
                              stops: [0.56, 1],
                            ),
                          ),
                        ),
                        if (video.statusBadges.isNotEmpty)
                          Positioned(
                            left: 8,
                            top: 8,
                            child: HgDramaBadges(
                              labels: video.statusBadges,
                              compact: true,
                            ),
                          ),
                        Positioned(
                          left: 9,
                          right: 8,
                          bottom: 8,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  video.episodeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  video.tags.isEmpty
                      ? video.author?.name ?? '短剧'
                      : video.tags.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HgDramaBadges extends StatelessWidget {
  const HgDramaBadges({super.key, required this.labels, this.compact = false});

  final List<String> labels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          if (index > 0) const SizedBox(width: 4),
          _DramaBadge(label: labels[index], compact: compact),
        ],
      ],
    );
  }
}

class _DramaBadge extends StatelessWidget {
  const _DramaBadge({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isOriginal = label.contains('原创');
    final isNew = label.contains('新片');
    final background = isOriginal
        ? HgColors.orange
        : isNew
        ? const Color(0xFFFFB84D)
        : const Color(0xFF2B2B2E);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isNew && !isOriginal ? HgColors.ink : Colors.white,
          fontSize: compact ? 8.5 : 9.5,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class HgTagChip extends StatelessWidget {
  const HgTagChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.onSurface
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(99),
      clipBehavior: Clip.antiAlias,
      child: HgInkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 12,
            vertical: compact ? 6 : 8,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? theme.colorScheme.surface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.68),
              fontSize: compact ? 10.5 : 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: HgColors.gold, size: 12),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class HgEmptyState extends StatelessWidget {
  const HgEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.5);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: muted, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: TextStyle(color: muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HgErrorState extends StatelessWidget {
  const HgErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HgEmptyState(
      icon: Icons.cloud_off_rounded,
      title: '内容没有加载出来',
      message: cleanError(error),
      actionLabel: '重新加载',
      onAction: onRetry,
    );
  }
}

enum HgLoadingVariant { grid, list }

class HgLoading extends StatefulWidget {
  const HgLoading({super.key, this.variant = HgLoadingVariant.grid});

  final HgLoadingVariant variant;

  @override
  State<HgLoading> createState() => _HgLoadingState();
}

class _HgLoadingState extends State<HgLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bone(
    BuildContext context, {
    required double progress,
    double? width,
    required double height,
    double radius = 16,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final edge = scheme.surfaceContainer;
    final peak = scheme.surfaceContainerHighest;
    final position = -2.4 + progress * 4.8;
    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(position, 0),
            end: Alignment(position + 1.15, 0),
            colors: [edge, peak, edge],
            stops: const [0.2, 0.5, 0.8],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_controller.value);
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < 640;
            if (widget.variant == HgLoadingVariant.list) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 24,
                  16,
                  compact ? 16 : 24,
                  30,
                ),
                child: Column(
                  children: List.generate(
                    6,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          _bone(
                            context,
                            progress: progress,
                            width: compact ? 76 : 92,
                            height: compact ? 98 : 112,
                            radius: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _bone(
                                  context,
                                  progress: progress,
                                  width: width * (index.isEven ? 0.42 : 0.52),
                                  height: 16,
                                  radius: 8,
                                ),
                                const SizedBox(height: 10),
                                _bone(
                                  context,
                                  progress: progress,
                                  width: width * 0.3,
                                  height: 11,
                                  radius: 6,
                                ),
                                const SizedBox(height: 18),
                                _bone(
                                  context,
                                  progress: progress,
                                  width: width * 0.34,
                                  height: 10,
                                  radius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            final columns = width >= 1000 ? 4 : 2;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 24,
                16,
                compact ? 16 : 24,
                30,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _bone(
                        context,
                        progress: progress,
                        width: compact ? 104 : 132,
                        height: 26,
                        radius: 9,
                      ),
                      const Spacer(),
                      _bone(
                        context,
                        progress: progress,
                        width: 52,
                        height: 14,
                        radius: 7,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: compact ? 11 : 15,
                      mainAxisSpacing: compact ? 14 : 18,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: columns == 2 ? 4 : 8,
                    itemBuilder: (context, index) => _bone(
                      context,
                      progress: progress,
                      height: double.infinity,
                      radius: 20,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  void run(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(duration, callback);
  }

  void dispose() {
    _timer?.cancel();
  }
}
