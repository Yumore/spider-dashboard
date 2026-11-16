import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../auth/app_controllers.dart';
import '../app_flags.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../services/hg_live_activity_service.dart';
import '../models/hg_download_models.dart';
import '../utils/hg_download_manager.dart';
import '../utils/hg_local_history.dart';
import '../widgets/hg_components.dart';
import '../utils/hg_player_display.dart';
import '../widgets/hg_share_sheet.dart';
import '../widgets/hg_video_controller.dart';
import '../widgets/secure_cover.dart';
import 'comments_sheet.dart';
import 'episodes_sheet.dart';
import 'login_sheet.dart';

class ShortVideoPage extends StatefulWidget {
  const ShortVideoPage({
    super.key,
    required this.videoIds,
    this.startIndex = 0,
    this.initialEpisode,
    this.initialPositionMs,
    this.title = '沉浸剧场',
  });

  final List<int> videoIds;
  final int startIndex;
  final int? initialEpisode;
  final int? initialPositionMs;
  final String title;

  @override
  State<ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<ShortVideoPage>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  final List<_EpisodeEntry> _entries = [];
  final Map<int, HgVideoDetail> _details = {};

  int _startDramaIndex = 0;
  int _lastLoadedDramaIndex = 0;
  int _currentPage = 0;
  int _currentPositionMs = 0;
  int _currentDurationMs = 0;
  bool _loading = true;
  bool _loadingNextDrama = false;
  bool _chromeVisible = true;
  final ValueNotifier<bool> _pageScrolling = ValueNotifier(false);
  bool _speedLocked = false;
  double _playbackSpeed = 1;
  bool get _previewOnly => kIsWeb && kHgWebPreviewOnly;
  String? _error;

  String _speedLabel(double speed) {
    final text = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(1)
        : speed.toStringAsFixed(2);
    return '${text}x';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _startDramaIndex = widget.videoIds.isEmpty
        ? 0
        : widget.startIndex.clamp(0, widget.videoIds.length - 1);
    _lastLoadedDramaIndex = _startDramaIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_saveCurrentProgress());
    _pageController.dispose();
    _pageScrolling.dispose();
    unawaited(HgLiveActivityService.end());
    unawaited(HgPlayerDisplay.reset());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveCurrentProgress());
    }
  }

  Future<void> _initialize() async {
    if (_previewOnly) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (widget.videoIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final videoId = widget.videoIds[_startDramaIndex];
      final api = context.read<HgApi>();
      final downloads = context.read<HgDownloadManager>();
      HgVideoDetail detail;
      try {
        detail = await api.video(videoId);
      } catch (error) {
        await downloads.restore();
        final cached = downloads.taskFor(videoId);
        if (cached == null || cached.episodes.isEmpty) rethrow;
        detail = _offlineDetail(cached);
      }
      final episodes = _episodesOf(detail);
      final history = await HgLocalHistory.find(detail.id);
      final wanted =
          widget.initialEpisode ??
          history?.lastEpisode ??
          episodes.first.number;
      final episodeIndex = episodes.indexWhere((item) => item.number == wanted);
      final initialIndex = episodeIndex < 0 ? 0 : episodeIndex;
      final initialPosition =
          widget.initialPositionMs ??
          (wanted == history?.lastEpisode ? history?.positionMs ?? 0 : 0);
      if (!mounted) return;
      _details[detail.id] = detail;
      _currentPositionMs = initialPosition;
      _currentDurationMs = history?.durationMs ?? 0;
      _entries.addAll(
        episodes.map(
          (episode) => _EpisodeEntry(
            detail: detail,
            episode: episode,
            resumePositionMs: episode.number == episodes[initialIndex].number
                ? initialPosition
                : 0,
          ),
        ),
      );
      setState(() {
        _loading = false;
        _currentPage = initialIndex;
      });
      unawaited(
        _recordHistory(
          _entries[_currentPage],
          positionMs: initialPosition,
          durationMs: _currentDurationMs,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(initialIndex);
        }
      });
      unawaited(
        context.read<HgApi>().prefetchPlaybackAround(
          detail,
          episodes[initialIndex].number,
        ),
      );
      unawaited(_ensureNextDrama());
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = cleanError(error);
        });
      }
    }
  }

  HgVideoDetail _offlineDetail(HgDownloadTask task) {
    final numbers = task.episodes.keys.toList()..sort();
    return HgVideoDetail(
      id: task.videoId,
      title: task.title,
      cover: task.cover,
      description: '已缓存到本机，可离线观看。',
      tags: task.tags,
      score: 0,
      episodeCount: numbers.length,
      totalEpisodes: task.totalEpisodes > 0
          ? task.totalEpisodes
          : numbers.length,
      episodes: numbers
          .map((number) => HgEpisode(number: number, title: '第 $number 集'))
          .toList(growable: false),
      author: null,
      isFinished: false,
      isOriginal: false,
    );
  }

  List<HgEpisode> _episodesOf(HgVideoDetail detail) {
    if (detail.episodes.isNotEmpty) return detail.episodes;
    final count = detail.totalEpisodes > 0
        ? detail.totalEpisodes
        : detail.episodeCount;
    if (count <= 0) {
      return const [HgEpisode(number: 1, title: '第 1 集')];
    }
    return List<HgEpisode>.generate(
      count.clamp(1, 500),
      (index) => HgEpisode(number: index + 1, title: '第 ${index + 1} 集'),
      growable: false,
    );
  }

  Future<void> _ensureNextDrama() async {
    if (_loadingNextDrama ||
        _lastLoadedDramaIndex >= widget.videoIds.length - 1 ||
        _entries.length - _currentPage > 8) {
      return;
    }
    _loadingNextDrama = true;
    try {
      final nextIndex = _lastLoadedDramaIndex + 1;
      final videoId = widget.videoIds[nextIndex];
      final detail =
          _details[videoId] ?? await context.read<HgApi>().video(videoId);
      final episodes = _episodesOf(detail);
      final history = await HgLocalHistory.find(videoId);
      final resumeEpisode = history?.lastEpisode ?? episodes.first.number;
      final resumePosition = history?.positionMs ?? 0;
      if (!mounted) return;
      _details[videoId] = detail;
      setState(() {
        _lastLoadedDramaIndex = nextIndex;
        _entries.addAll(
          episodes.map(
            (episode) => _EpisodeEntry(
              detail: detail,
              episode: episode,
              resumePositionMs: episode.number == resumeEpisode
                  ? resumePosition
                  : 0,
            ),
          ),
        );
      });
    } catch (_) {
      // 预加载失败不打断当前播放，到边界时会再次尝试。
    } finally {
      _loadingNextDrama = false;
    }
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    unawaited(_saveCurrentProgress());
    setState(() {
      _currentPage = index;
      _currentPositionMs = _entries[index].resumePositionMs;
      _currentDurationMs = 0;
      _chromeVisible = true;
    });
    unawaited(_recordHistory(_entries[index]));
    unawaited(_prefetchAround(index));
    unawaited(_ensureNextDrama());
  }

  Future<void> _recordHistory(
    _EpisodeEntry entry, {
    int? positionMs,
    int? durationMs,
  }) {
    return HgLocalHistory.save(
      videoId: entry.detail.id,
      title: entry.detail.title,
      cover: entry.detail.cover,
      episode: entry.episode.number,
      totalEpisodes: entry.detail.totalEpisodes > 0
          ? entry.detail.totalEpisodes
          : entry.detail.episodeCount,
      positionMs: positionMs ?? _currentPositionMs,
      durationMs: durationMs ?? _currentDurationMs,
    );
  }

  Future<void> _saveCurrentProgress() async {
    if (_entries.isEmpty ||
        _currentPage < 0 ||
        _currentPage >= _entries.length) {
      return;
    }
    await _recordHistory(
      _entries[_currentPage],
      positionMs: _currentPositionMs,
      durationMs: _currentDurationMs,
    );
  }

  void _handleProgress(Duration position, Duration duration) {
    _currentPositionMs = position.inMilliseconds;
    _currentDurationMs = duration.inMilliseconds;
    if (_entries.isEmpty ||
        _currentPage < 0 ||
        _currentPage >= _entries.length) {
      return;
    }
    _entries[_currentPage].resumePositionMs = _currentPositionMs;
    unawaited(
      _recordHistory(
        _entries[_currentPage],
        positionMs: _currentPositionMs,
        durationMs: _currentDurationMs,
      ),
    );
  }

  Future<void> _prefetchAround(int index) async {
    if (index < 0 || index >= _entries.length) return;
    final entry = _entries[index];
    await context.read<HgApi>().prefetchPlaybackAround(
      entry.detail,
      entry.episode.number,
    );
  }

  void _setPageScrolling(bool value) {
    _pageScrolling.value = value;
  }

  Future<void> _playNext() async {
    if (_currentPage < _entries.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _ensureNextDrama();
    if (mounted && _currentPage < _entries.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  void _cleanScreen() => setState(() => _chromeVisible = false);

  void _cycleSpeed() {
    const speeds = [1.0, 1.25, 1.5, 2.0];
    final index = speeds.indexOf(_playbackSpeed);
    setState(() => _playbackSpeed = speeds[(index + 1) % speeds.length]);
  }

  Future<void> _openEpisodesSheet() async {
    if (_entries.isEmpty) return;
    final current = _entries[_currentPage];
    final selected = await showEpisodesSheet(
      context,
      detail: current.detail,
      currentEpisode: current.episode.number,
    );
    if (!mounted || selected == null) return;
    final target = _entries.indexWhere(
      (entry) =>
          entry.detail.id == current.detail.id &&
          entry.episode.number == selected,
    );
    if (target < 0) return;
    await _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _entries.isEmpty ? null : _entries[_currentPage];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;
            final stage = Stack(
              fit: StackFit.expand,
              children: [
                if (_previewOnly)
                  _WebPreviewBlocked(
                    onOpenRelease: () async {
                      final uri = Uri.tryParse(kHgLatestReleaseUrl);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  )
                else if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                else if (_error != null)
                  Center(
                    child: _InlinePlaybackError(
                      error: _error!,
                      onRetry: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        unawaited(_initialize());
                      },
                    ),
                  )
                else if (_entries.isEmpty)
                  const HgEmptyState(
                    icon: Icons.movie_outlined,
                    title: '没有可播放的短剧',
                  )
                else
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification) {
                        _setPageScrolling(true);
                      } else if (notification is ScrollEndNotification) {
                        _setPageScrolling(false);
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      physics: const PageScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      allowImplicitScrolling: true,
                      itemCount: _entries.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return _EpisodePlayer(
                          key: ValueKey(
                            '${entry.detail.id}-${entry.episode.number}',
                          ),
                          detail: entry.detail,
                          episode: entry.episode,
                          resumePositionMs: entry.resumePositionMs,
                          active: index == _currentPage,
                          scrolling: _pageScrolling,
                          prepare: (index - _currentPage).abs() <= 4,
                          chromeVisible: _chromeVisible,
                          speedLocked: _speedLocked,
                          playbackSpeed: _playbackSpeed,
                          onCycleSpeed: _cycleSpeed,
                          onToggleChrome: _toggleChrome,
                          onCleanScreen: _cleanScreen,
                          onOpenEpisodes: _openEpisodesSheet,
                          onSpeedLockChanged: (value) {
                            if (mounted) setState(() => _speedLocked = value);
                          },
                          onProgress: _handleProgress,
                          onEnded: _playNext,
                        );
                      },
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _chromeVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_chromeVisible,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Row(
                            children: [
                              _VideoCircleButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  current == null
                                      ? widget.title
                                      : '第 ${current.episode.number} 集',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _cycleSpeed,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        color: Colors.white,
                                        size: 18,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 9,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _speedLabel(
                                          _speedLocked ? 2 : _playbackSpeed,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 9,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _VideoCircleButton(
                                icon: Icons.visibility_off_outlined,
                                onTap: _cleanScreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
            if (!desktop) return stage;
            return Center(
              child: SizedBox(
                width: 520,
                height: constraints.maxHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: stage,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EpisodeEntry {
  _EpisodeEntry({
    required this.detail,
    required this.episode,
    this.resumePositionMs = 0,
  });

  final HgVideoDetail detail;
  final HgEpisode episode;
  int resumePositionMs;
}

class _EpisodePlayer extends StatefulWidget {
  const _EpisodePlayer({
    super.key,
    required this.detail,
    required this.episode,
    required this.resumePositionMs,
    required this.active,
    required this.scrolling,
    required this.prepare,
    required this.chromeVisible,
    required this.speedLocked,
    required this.playbackSpeed,
    required this.onCycleSpeed,
    required this.onToggleChrome,
    required this.onCleanScreen,
    required this.onOpenEpisodes,
    required this.onSpeedLockChanged,
    required this.onProgress,
    required this.onEnded,
  });

  final HgVideoDetail detail;
  final HgEpisode episode;
  final int resumePositionMs;
  final bool active;
  final ValueListenable<bool> scrolling;
  final bool prepare;
  final bool chromeVisible;
  final bool speedLocked;
  final double playbackSpeed;
  final VoidCallback onCycleSpeed;
  final VoidCallback onToggleChrome;
  final VoidCallback onCleanScreen;
  final VoidCallback onOpenEpisodes;
  final ValueChanged<bool> onSpeedLockChanged;
  final void Function(Duration position, Duration duration) onProgress;
  final Future<void> Function() onEnded;

  @override
  State<_EpisodePlayer> createState() => _EpisodePlayerState();
}

class _EpisodePlayerState extends State<_EpisodePlayer> {
  HgVideoController? _controller;
  bool _loading = true;
  bool _initializing = false;
  bool _speedBoosting = false;
  bool _speedUnlockedInGesture = false;
  String? _error;
  DateTime? _lastProgressAt;
  DateTime? _lastLiveActivityAt;
  bool _scrubbing = false;
  bool _resumeAfterScrub = false;
  Duration _scrubPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loading = widget.prepare;
    widget.scrolling.addListener(_handleScrollingChanged);
    if (widget.prepare) unawaited(_initializeWhenReady());
  }

  @override
  void didUpdateWidget(covariant _EpisodePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.prepare && widget.prepare) ||
        (!oldWidget.active && widget.active)) {
      unawaited(_initializeWhenReady());
    }
    if (oldWidget.scrolling != widget.scrolling) {
      oldWidget.scrolling.removeListener(_handleScrollingChanged);
      widget.scrolling.addListener(_handleScrollingChanged);
    }
    if (oldWidget.speedLocked != widget.speedLocked ||
        oldWidget.playbackSpeed != widget.playbackSpeed) {
      unawaited(
        _controller?.setPlaybackSpeed(
          widget.speedLocked ? 2 : widget.playbackSpeed,
        ),
      );
    }
    if (oldWidget.active != widget.active) {
      _syncPlaybackState();
    }
  }

  bool get _showVideo => widget.active;

  void _handleScrollingChanged() => _syncPlaybackState();

  void _syncPlaybackState() {
    if (!_showVideo) _emitProgress(force: true);
    if (_showVideo) {
      final controller = _controller;
      if (controller == null) {
        unawaited(_initializeWhenReady());
      } else {
        unawaited(controller.play());
      }
    } else {
      unawaited(_controller?.pause());
    }
  }

  Future<void> _handleControllerChanged() async {
    final controller = _controller;
    if (controller != null && controller.hasError) {
      final message = _friendlyPlaybackError(
        controller.errorDescription ?? '视频源加载失败',
      );
      _controller = null;
      controller.removeListener(_handleControllerChanged);
      controller.dispose();
      if (!widget.active) return;
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
      await _initializePlayback();
      if (mounted && _controller == null && _error == null) {
        setState(() {
          _loading = false;
          _error = message;
        });
      }
      return;
    }
    _emitProgress();
  }

  void _emitProgress({bool force = false}) {
    if (!widget.active || _scrubbing) return;
    final controller = _controller;
    if (controller == null || !controller.isReady) return;
    final duration = controller.duration;
    if (duration <= Duration.zero) return;
    final now = DateTime.now();
    final last = _lastProgressAt;
    if (!force &&
        last != null &&
        now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastProgressAt = now;
    widget.onProgress(controller.position, duration);
    final liveNow = DateTime.now();
    if (_lastLiveActivityAt == null ||
        liveNow.difference(_lastLiveActivityAt!) >
            const Duration(seconds: 20)) {
      _lastLiveActivityAt = liveNow;
      unawaited(
        HgLiveActivityService.showOrUpdate(
          videoId: widget.detail.id,
          title: widget.detail.title,
          cover: widget.detail.cover,
          tags: widget.detail.tags,
          episode: widget.episode.number,
          totalEpisodes: widget.detail.totalEpisodes > 0
              ? widget.detail.totalEpisodes
              : widget.detail.episodeCount,
          progress: duration.inMilliseconds <= 0
              ? 0
              : controller.position.inMilliseconds / duration.inMilliseconds,
          deepLink: 'guomu://video/${widget.detail.id}',
        ),
      );
    }
  }

  Future<void> _initializeWhenReady() async {
    if (!widget.prepare || _initializing || _controller != null) return;
    if (!widget.active) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    if (!mounted || !widget.prepare || _initializing || _controller != null) {
      return;
    }
    await _initializePlayback();
  }

  Future<void> _initializePlayback() async {
    if (_initializing || _controller != null) return;
    _initializing = true;
    try {
      final downloads = context.read<HgDownloadManager>();
      final api = context.read<HgApi>();
      Object? lastError;
      var allowNetworkRetry = true;
      for (var attempt = 0; attempt < 2; attempt++) {
        if (!mounted) return;
        final localPath = await downloads.localPlaylist(
          widget.detail.id,
          widget.episode.number,
        );
        if (!mounted) return;
        HgVideoController? controller;
        try {
          final info = localPath == null
              ? await api.playback(widget.detail.id, widget.episode.number)
              : null;
          if (!mounted) return;
          final mediaHeaders = <String, String>{
            ...hgMediaHeaders(),
            if (info != null && info.cdnAuthKey.isNotEmpty)
              info.cdnAuthKey: info.cdnAuthValue,
            if (info != null && info.cdnApp.isNotEmpty)
              'x-cdn-app': info.cdnApp,
          };
          controller = HgVideoController(
            url: info?.videoUrl ?? 'file://${localPath ?? ''}',
            localPath: localPath,
            headers: mediaHeaders,
            onEnded: () {
              if (widget.active) {
                _emitProgress(force: true);
                unawaited(widget.onEnded());
              }
            },
          );
          await controller.initialize();
          if (!mounted) {
            controller.dispose();
            return;
          }
          _controller = controller;
          controller.addListener(_handleControllerChanged);
          final resume = Duration(milliseconds: widget.resumePositionMs);
          if (resume > const Duration(seconds: 1) &&
              controller.duration >
                  resume + const Duration(milliseconds: 800)) {
            await controller.seekTo(resume);
          }
          await controller.setPlaybackSpeed(
            widget.speedLocked ? 2 : widget.playbackSpeed,
          );
          if (_showVideo) {
            await controller.play();
          } else {
            await controller.pause();
          }
          setState(() => _loading = false);
          return;
        } catch (error) {
          controller?.dispose();
          lastError = error;
          final isNetworkSource = localPath == null;
          if (attempt == 0 && allowNetworkRetry && isNetworkSource) {
            allowNetworkRetry = false;
            await Future<void>.delayed(const Duration(milliseconds: 420));
            continue;
          }
          break;
        }
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _friendlyPlaybackError(lastError ?? '视频加载失败');
        });
      }
    } finally {
      _initializing = false;
    }
  }

  String _friendlyPlaybackError(Object error) {
    final text = cleanError(error).toLowerCase();
    if (text.contains('source error') ||
        text.contains('videoerror') ||
        text.contains('platformexception') ||
        text.contains('http')) {
      return '视频源加载失败，请检查网络后重试';
    }
    return cleanError(error);
  }

  @override
  void dispose() {
    widget.scrolling.removeListener(_handleScrollingChanged);
    final controller = _controller;
    if (controller != null) {
      _emitProgress(force: true);
      controller.removeListener(_handleControllerChanged);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (!widget.chromeVisible) {
      widget.onToggleChrome();
      return;
    }
    final controller = _controller;
    if (controller == null) {
      if (_error != null) {
        setState(() {
          _loading = true;
          _error = null;
        });
        await _initializePlayback();
      }
      return;
    }
    await controller.toggle();
    _emitProgress(force: true);
  }

  Duration _positionForFraction(double fraction) {
    final duration = _controller?.duration ?? Duration.zero;
    if (duration <= Duration.zero) return Duration.zero;
    final safeFraction = fraction.clamp(0.0, 1.0);
    return Duration(
      milliseconds: (duration.inMilliseconds * safeFraction).round(),
    );
  }

  void _startScrubbing(double fraction) {
    final controller = _controller;
    if (controller == null || controller.duration <= Duration.zero) return;
    HapticFeedback.selectionClick();
    _resumeAfterScrub = controller.isPlaying;
    if (controller.isPlaying) unawaited(controller.pause());
    setState(() {
      _scrubbing = true;
      _scrubPosition = _positionForFraction(fraction);
    });
  }

  void _updateScrubbing(double fraction) {
    if (!_scrubbing) return;
    setState(() => _scrubPosition = _positionForFraction(fraction));
  }

  Future<void> _finishScrubbing(double fraction) async {
    final controller = _controller;
    if (controller == null) return;
    final target = _positionForFraction(fraction);
    await controller.seekTo(target);
    widget.onProgress(target, controller.duration);
    if (_resumeAfterScrub) await controller.play();
    if (mounted) {
      setState(() {
        _scrubbing = false;
        _scrubPosition = target;
      });
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _seekFromTap(double fraction) async {
    final controller = _controller;
    if (controller == null) return;
    final target = _positionForFraction(fraction);
    await controller.seekTo(target);
    widget.onProgress(target, controller.duration);
    HapticFeedback.selectionClick();
  }

  Future<void> _startBoost(LongPressStartDetails details) async {
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final x = details.localPosition.dx;
    final onSide = x < width * 0.3 || x > width * 0.7;
    if (!onSide) return;
    setState(() {
      _speedBoosting = true;
      _speedUnlockedInGesture = false;
    });
    await _controller?.setPlaybackSpeed(2);
  }

  void _moveBoost(LongPressMoveUpdateDetails details) {
    if (!_speedBoosting) return;
    if (!widget.speedLocked && details.offsetFromOrigin.dy < -46) {
      HapticFeedback.mediumImpact();
      widget.onSpeedLockChanged(true);
      return;
    }
    if (widget.speedLocked && details.offsetFromOrigin.dy > 46) {
      HapticFeedback.mediumImpact();
      setState(() => _speedUnlockedInGesture = true);
      widget.onSpeedLockChanged(false);
      unawaited(_controller?.setPlaybackSpeed(widget.playbackSpeed));
    }
  }

  Future<void> _endBoost() async {
    if (!widget.speedLocked || _speedUnlockedInGesture) {
      await _controller?.setPlaybackSpeed(widget.playbackSpeed);
    }
    if (mounted) setState(() => _speedBoosting = false);
  }

  Future<void> _toggleLike() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    HapticFeedback.lightImpact();
    final auth = context.read<AuthController>();
    try {
      await auth.toggleLike(widget.detail.id, widget.episode.number);
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    }
  }

  Future<void> _toggleFavorite() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthController>();
    try {
      await auth.toggleFavorite(widget.detail.id);
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    }
  }

  Future<void> _enterLandscape() => HgPlayerDisplay.enterLandscape();

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setVolume(controller.volume > 0 ? 0 : 1);
    HapticFeedback.selectionClick();
  }

  void _share() {
    final url = '${resolveHgApiBaseUrl()}/video/${widget.detail.id}/';
    unawaited(
      showHgShareSheet(
        context,
        title: widget.detail.title,
        subtitle:
            '第 ${widget.episode.number} 集 · ${widget.detail.episodeLabel}',
        url: url,
      ),
    );
  }

  String _speedText(double speed) {
    final text = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(1)
        : speed.toStringAsFixed(2);
    return '${text}x';
  }

  Widget _buildLandscapeChrome(
    BuildContext context, {
    required bool liked,
    required bool favorite,
  }) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnimatedOpacity(
      opacity: widget.chromeVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !widget.chromeVisible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Colors.transparent,
                    Color(0x99000000),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Positioned(
              top: top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _VideoCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.detail.title} · 第 ${widget.episode.number} 集',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                  _VideoCircleButton(
                    icon: Icons.ios_share_rounded,
                    onTap: _share,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              top: top + 68,
              child: _VideoCircleButton(
                icon: _controller != null && _controller!.volume <= 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                onTap: _toggleMute,
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 8 + bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller != null)
                    AnimatedBuilder(
                      animation: _controller!,
                      builder: (context, _) => _SeekBar(
                        position: _scrubbing
                            ? _scrubPosition
                            : _controller!.position,
                        duration: _controller!.duration,
                        scrubbing: _scrubbing,
                        showTimeLabels: true,
                        onScrubStart: _startScrubbing,
                        onScrubUpdate: _updateScrubbing,
                        onScrubEnd: _finishScrubbing,
                        onTapSeek: _seekFromTap,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _LandscapeAction(
                        icon: favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: favorite ? HgColors.gold : Colors.white,
                        label: formatCount(widget.detail.collectCount),
                        onTap: _toggleFavorite,
                      ),
                      _LandscapeAction(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: formatCount(widget.detail.commentCount),
                        onTap: () => showCommentsSheet(
                          context,
                          videoId: widget.detail.id,
                          episode: widget.episode.number,
                          title: widget.detail.title,
                          totalComments: widget.detail.commentCount,
                        ),
                      ),
                      _LandscapeAction(
                        icon: liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: liked ? HgColors.orange : Colors.white,
                        label: formatCount(widget.detail.likeCount),
                        onTap: _toggleLike,
                      ),
                      _LandscapeAction(
                        icon: Icons.ios_share_rounded,
                        label: '分享',
                        onTap: _share,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onCycleSpeed,
                        child: Text(
                          _speedText(
                            widget.speedLocked ? 2 : widget.playbackSpeed,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => unawaited(HgPlayerDisplay.reset()),
                        child: const Icon(
                          Icons.fullscreen_exit_rounded,
                          color: Colors.white,
                          size: 23,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final liked = auth.isLiked(widget.detail.id, widget.episode.number);
    final favorite = auth.isFavorite(widget.detail.id);
    final chromeOpacity = widget.chromeVisible ? 1.0 : 0.0;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isWideVideo = (_controller?.aspectRatio ?? 0) > 1.2;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: widget.scrolling,
            builder: (context, scrolling, child) {
              final showVideo = widget.active;
              return Stack(
                fit: StackFit.expand,
                children: [
                  HgCoverImage(
                    url: widget.detail.cover,
                    title: widget.detail.title,
                  ),
                  if (_controller != null && showVideo)
                    _controller!.buildView(),
                ],
              );
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x36000000),
                  Colors.transparent,
                  Color(0x08000000),
                  Color(0xE8000000),
                ],
                stops: [0, 0.28, 0.58, 1],
              ),
            ),
          ),
          if (_loading)
            const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.3,
                ),
              ),
            )
          else if (_error != null)
            Center(
              child: _InlinePlaybackError(
                error: _error!,
                onRetry: _initializePlayback,
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayback,
              onLongPressStart: _startBoost,
              onLongPressMoveUpdate: _moveBoost,
              onLongPressEnd: (_) => _endBoost(),
              onLongPressCancel: () => _endBoost(),
              child: const SizedBox.expand(),
            ),
          ),
          if (!isLandscape)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: chromeOpacity,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: IgnorePointer(
                  ignoring: !widget.chromeVisible,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 18,
                        right: 76,
                        bottom: 78,
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.detail.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '第 ${widget.episode.number} 集 · ${widget.detail.episodeLabel}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 78,
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: _ActionRail(
                            liked: liked,
                            favorite: favorite,
                            likeCount: widget.detail.likeCount,
                            commentCount: widget.detail.commentCount,
                            collectCount: widget.detail.collectCount,
                            onLike: _toggleLike,
                            onComments: () => showCommentsSheet(
                              context,
                              videoId: widget.detail.id,
                              episode: widget.episode.number,
                              title: widget.detail.title,
                              totalComments: widget.detail.commentCount,
                            ),
                            onFavorite: _toggleFavorite,
                            onShare: _share,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 22,
                        child: SafeArea(
                          top: false,
                          child: _WatchAllBar(
                            label:
                                '选集 · 全 ${widget.detail.totalEpisodes > 0 ? widget.detail.totalEpisodes : (widget.detail.episodeCount > 0 ? widget.detail.episodeCount : widget.detail.episodes.length)} 集 · 当前第 ${widget.episode.number} 集',
                            onTap: widget.onOpenEpisodes,
                          ),
                        ),
                      ),
                      if (_controller != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 0,
                          child: SafeArea(
                            top: false,
                            child: AnimatedBuilder(
                              animation: _controller!,
                              builder: (context, child) => _SeekBar(
                                position: _scrubbing
                                    ? _scrubPosition
                                    : _controller!.position,
                                duration: _controller!.duration,
                                scrubbing: _scrubbing,
                                showTimeLabels: false,
                                onScrubStart: _startScrubbing,
                                onScrubUpdate: _updateScrubbing,
                                onScrubEnd: _finishScrubbing,
                                onTapSeek: _seekFromTap,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (isLandscape)
            _buildLandscapeChrome(context, liked: liked, favorite: favorite),
          if (_speedBoosting || widget.speedLocked)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 70,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: _SpeedLockHint(locked: widget.speedLocked),
                ),
              ),
            ),
          if (!isLandscape && isWideVideo && widget.chromeVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 74,
              child: Center(child: _LandscapeEntry(onTap: _enterLandscape)),
            ),
          if (_controller != null && !_loading)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller!,
                builder: (context, child) {
                  if (_controller!.isPlaying || !widget.chromeVisible) {
                    return const SizedBox.shrink();
                  }
                  return Center(
                    child: Icon(
                      _controller!.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 54,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 14),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.scrubbing,
    required this.showTimeLabels,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    required this.onTapSeek,
  });

  final Duration position;
  final Duration duration;
  final bool scrubbing;
  final bool showTimeLabels;
  final ValueChanged<double> onScrubStart;
  final ValueChanged<double> onScrubUpdate;
  final ValueChanged<double> onScrubEnd;
  final ValueChanged<double> onTapSeek;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SpeedLockHint extends StatelessWidget {
  const _SpeedLockHint({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(100),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        child: Row(
          key: ValueKey<bool>(locked),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              locked ? Icons.swipe_down_rounded : Icons.swipe_up_rounded,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              locked ? '继续长按两侧，下滑解除 2 倍速' : '上滑锁定 2 倍速',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragFraction;

  double get _currentFraction {
    final durationMs = widget.duration.inMilliseconds;
    if (durationMs <= 0) return 0;
    return (widget.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
  }

  double _fractionAt(Offset localPosition) {
    final width = context.size?.width ?? 1;
    return (localPosition.dx / width).clamp(0.0, 1.0);
  }

  void _start(DragStartDetails details) {
    final fraction = _fractionAt(details.localPosition);
    setState(() => _dragFraction = fraction);
    widget.onScrubStart(fraction);
  }

  void _update(DragUpdateDetails details) {
    final fraction = _fractionAt(details.localPosition);
    setState(() => _dragFraction = fraction);
    widget.onScrubUpdate(fraction);
  }

  void _end(DragEndDetails details) {
    final fraction = _dragFraction ?? _currentFraction;
    widget.onScrubEnd(fraction);
  }

  @override
  void didUpdateWidget(covariant _SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrubbing && !widget.scrubbing) {
      _dragFraction = null;
    }
  }

  String _time(Duration value) {
    final seconds = value.inSeconds.clamp(0, 99 * 60 * 60);
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _dragFraction ?? _currentFraction;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bubbleLeft = (width * fraction - 29).clamp(0.0, width - 58);
        return Semantics(
          slider: true,
          label: '播放进度',
          value: '${(fraction * 100).round()}%',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showTimeLabels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Text(
                        _time(widget.position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _time(widget.duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    widget.onTapSeek(_fractionAt(details.localPosition)),
                onHorizontalDragStart: _start,
                onHorizontalDragUpdate: _update,
                onHorizontalDragEnd: _end,
                child: SizedBox(
                  height: widget.showTimeLabels ? 18 : 20,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 3,
                          width: width,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: widget.scrubbing
                                  ? Colors.white
                                  : HgColors.orange,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment(-1 + fraction * 2, 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: widget.scrubbing ? 13 : 8,
                          height: widget.scrubbing ? 13 : 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.scrubbing)
                        Positioned(
                          left: bubbleLeft,
                          top: -25,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _time(widget.position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.liked,
    required this.favorite,
    required this.likeCount,
    required this.commentCount,
    required this.collectCount,
    required this.onLike,
    required this.onComments,
    required this.onFavorite,
    required this.onShare,
  });

  final bool liked;
  final bool favorite;
  final int likeCount;
  final int commentCount;
  final int collectCount;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onFavorite;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailAction(
          icon: favorite ? Icons.star_rounded : Icons.star_border_rounded,
          color: favorite ? HgColors.gold : Colors.white,
          label: formatCount(collectCount),
          onTap: onFavorite,
        ),
        _RailAction(
          icon: Icons.chat_bubble_rounded,
          label: formatCount(commentCount),
          onTap: onComments,
        ),
        _RailAction(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? HgColors.orange : Colors.white,
          label: formatCount(likeCount),
          onTap: onLike,
        ),
        _RailAction(icon: Icons.ios_share_rounded, label: '分享', onTap: onShare),
      ],
    );
  }
}

class _WatchAllBar extends StatelessWidget {
  const _WatchAllBar({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white70,
                size: 21,
              ),
              const SizedBox(width: 11),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandscapeAction extends StatelessWidget {
  const _LandscapeAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Row(
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandscapeEntry extends StatelessWidget {
  const _LandscapeEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fullscreen_rounded,
            color: Colors.white,
            size: 17,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
          const SizedBox(width: 5),
          const Text(
            '全屏观看',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              width: 43,
              height: 43,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 190),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.72,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Icon(
                  icon,
                  key: ValueKey<IconData>(icon),
                  color: color,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebPreviewBlocked extends StatelessWidget {
  const _WebPreviewBlocked({required this.onOpenRelease});

  final VoidCallback onOpenRelease;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 34),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.open_in_new_rounded,
              color: Colors.white70,
              size: 30,
            ),
            const SizedBox(height: 12),
            const Text(
              '网页预览不提供播放',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请前往 GitHub Releases 下载最新安装包。网页预览不会加载视频，也不会发起播放请求。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onOpenRelease,
              child: const Text('前往 Releases'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlinePlaybackError extends StatelessWidget {
  const _InlinePlaybackError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 36),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 28),
          const SizedBox(height: 9),
          const Text(
            '播放暂时中断',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(112, 38),
            ),
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}

class _VideoCircleButton extends StatelessWidget {
  const _VideoCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 39,
        height: 39,
        child: Icon(
          icon,
          color: Colors.white,
          size: 19,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
        ),
      ),
    );
  }
}
