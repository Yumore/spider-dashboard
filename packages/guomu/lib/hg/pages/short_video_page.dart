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
import '../utils/hg_player_gestures.dart';
import '../services/hg_live_activity_service.dart';
import '../services/hg_now_playing_service.dart';
import '../services/hg_wake_lock_service.dart';
import '../models/hg_download_models.dart';
import '../utils/hg_download_manager.dart';
import '../utils/hg_local_history.dart';
import '../widgets/hg_components.dart';
import '../utils/hg_player_display.dart';
import '../widgets/hg_share_sheet.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/hg_video_controller.dart';
import '../widgets/hg_player_seek_bar.dart';
import '../widgets/hg_playback_feedback.dart';
import '../widgets/secure_cover.dart';
import 'comments_sheet.dart';
import 'episodes_sheet.dart';
import 'login_sheet.dart';
import '../widgets/hg_pressable.dart';

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
  bool _speedLocked = false;
  bool _applicationActive = true;
  bool _activeEpisodePlaying = false;
  final ValueNotifier<double> _speed = ValueNotifier<double>(1);
  double get _playbackSpeed => _speed.value;
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
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _applicationActive =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _pageController = PageController();
    _startDramaIndex = widget.videoIds.isEmpty
        ? 0
        : widget.startIndex.clamp(0, widget.videoIds.length - 1);
    _lastLoadedDramaIndex = _startDramaIndex;
    if (!_previewOnly) unawaited(HgPlayerDisplay.enterAutoRotate());
    unawaited(_syncWakeLock());
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_saveCurrentProgress());
    _pageController.dispose();
    _speed.dispose();
    unawaited(HgLiveActivityService.end());
    unawaited(HgNowPlayingService.clear());
    unawaited(HgWakeLockService.release());
    if (!_previewOnly) unawaited(HgPlayerDisplay.reset());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _applicationActive = state == AppLifecycleState.resumed;
    if (!_applicationActive) {
      unawaited(_saveCurrentProgress());
    }
    unawaited(_syncWakeLock());
  }

  Future<void> _syncWakeLock() {
    if (_previewOnly) return HgWakeLockService.release();
    return HgWakeLockService.update(
      playing: _activeEpisodePlaying,
      applicationActive: _applicationActive,
    );
  }

  void _onEpisodePlaybackChanged(int index, bool playing) {
    if (!mounted || index != _currentPage || _activeEpisodePlaying == playing) {
      return;
    }
    _activeEpisodePlaying = playing;
    unawaited(_syncWakeLock());
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
          (episodeIndex >= 0 && wanted == history?.lastEpisode
              ? history?.positionMs ?? 0
              : 0);
      if (!mounted) return;
      _details[detail.id] = detail;
      _currentPositionMs = initialPosition;
      _currentDurationMs = episodeIndex >= 0 && wanted == history?.lastEpisode
          ? history?.durationMs ?? 0
          : 0;
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
    _activeEpisodePlaying = false;
    unawaited(_syncWakeLock());
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

  void _handleProgress(
    _EpisodeEntry entry,
    Duration position,
    Duration duration,
  ) {
    entry.resumePositionMs = position.inMilliseconds;
    if (_entries.isNotEmpty && identical(_entries[_currentPage], entry)) {
      _currentPositionMs = position.inMilliseconds;
      _currentDurationMs = duration.inMilliseconds;
    } else if (_entries.isNotEmpty &&
        _entries[_currentPage].detail.id == entry.detail.id) {
      // A late final update from the departing episode must not replace this
      // drama's newly selected episode in the shared watch history.
      return;
    }
    unawaited(
      _recordHistory(
        entry,
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
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

  void _cleanScreen() => setState(() => _chromeVisible = false);

  void _showChrome() {
    if (!_chromeVisible) setState(() => _chromeVisible = true);
  }

  Future<void> _openSpeedSheet() async {
    final selected = await showHgAdaptiveSheetBuilder<double>(
      context,
      initialSize: 0.46,
      minSize: 0.3,
      maxSize: 0.86,
      barrierColor: Colors.black.withValues(alpha: 0.36),
      builder: (_) => _PlaybackSpeedSheet(
        current: _speedLocked ? 2 : _playbackSpeed,
        locked: _speedLocked,
      ),
    );
    if (!mounted || selected == null) return;
    HapticFeedback.selectionClick();
    _speed.value = selected;
    setState(() => _speedLocked = false);
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
    // A chosen episode is a direct destination. Scrolling across dozens of pages
    // starts their players and writes intermediate episodes into watch history.
    _pageController.jumpToPage(target);
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
            final landscape =
                MediaQuery.orientationOf(context) == Orientation.landscape;
            final desktop = kIsWeb && constraints.maxWidth >= 900;
            final landscapeControls = landscape && !desktop && current != null;
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
                  PageView.builder(
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
                        landscape: landscapeControls,
                        prepare: (index - _currentPage).abs() <= 4,
                        chromeVisible: _chromeVisible,
                        speedLocked: _speedLocked,
                        playbackSpeedListenable: _speed,
                        onCycleSpeed: () => unawaited(_openSpeedSheet()),
                        onShowChrome: _showChrome,
                        onHideChrome: _cleanScreen,
                        onOpenEpisodes: _openEpisodesSheet,
                        onSpeedLockChanged: (value) {
                          if (mounted) setState(() => _speedLocked = value);
                        },
                        onProgress: (position, duration) =>
                            _handleProgress(entry, position, duration),
                        onPlaybackStateChanged: (playing) =>
                            _onEpisodePlaybackChanged(index, playing),
                        onEnded: _playNext,
                      );
                    },
                  ),
                if (!landscapeControls)
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
                                  label: '返回',
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
                                HgPressable(
                                  key: const ValueKey('hg-speed-button'),
                                  onTap: () => unawaited(_openSpeedSheet()),
                                  haptic: true,
                                  semanticLabel:
                                      '播放速度 ${_speedLabel(_speedLocked ? 2 : _playbackSpeed)}',
                                  pressedOpacity: 0.55,
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
                                  label: '清屏观看',
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
            final player = !desktop
                ? stage
                : Center(
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
            return PopScope(
              canPop: kIsWeb || !landscape,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && !kIsWeb && landscape) {
                  unawaited(HgPlayerDisplay.exitLandscape());
                  _showChrome();
                }
              },
              child: player,
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
    required this.landscape,
    required this.prepare,
    required this.chromeVisible,
    required this.speedLocked,
    required this.playbackSpeedListenable,
    required this.onCycleSpeed,
    required this.onShowChrome,
    required this.onHideChrome,
    required this.onOpenEpisodes,
    required this.onSpeedLockChanged,
    required this.onProgress,
    required this.onPlaybackStateChanged,
    required this.onEnded,
  });

  final HgVideoDetail detail;
  final HgEpisode episode;
  final int resumePositionMs;
  final bool active;
  final bool landscape;
  final bool prepare;
  final bool chromeVisible;
  final bool speedLocked;
  final ValueListenable<double> playbackSpeedListenable;
  final VoidCallback onCycleSpeed;
  final VoidCallback onShowChrome;
  final VoidCallback onHideChrome;
  final Future<void> Function() onOpenEpisodes;
  final ValueChanged<bool> onSpeedLockChanged;
  final void Function(Duration position, Duration duration) onProgress;
  final ValueChanged<bool> onPlaybackStateChanged;
  final Future<void> Function() onEnded;

  @override
  State<_EpisodePlayer> createState() => _EpisodePlayerState();
}

class _EpisodePlayerState extends State<_EpisodePlayer> {
  HgVideoController? _controller;
  bool _loading = true;
  bool _initializing = false;
  bool _recovering = false;
  int _runtimeRetries = 0;
  Duration? _recoveryPosition;
  bool _speedBoosting = false;
  bool? _speedLockInGesture;
  String? _error;
  DateTime? _lastProgressAt;
  DateTime? _lastLiveActivityAt;
  DateTime? _lastNowPlayingAt;
  bool _scrubbing = false;
  bool _seeking = false;
  bool _horizontalSeeking = false;
  bool _resumeAfterHorizontalSeek = false;
  double _horizontalSeekDelta = 0;
  Duration _horizontalSeekStart = Duration.zero;
  Duration _scrubPosition = Duration.zero;
  Timer? _chromeTimer;
  bool? _lastPlaying;
  bool _wideVideo = false;
  int _pointersDown = 0;
  bool _resumeAfterScrub = false;
  Future<void>? _pauseForSeek;
  bool? _doubleTapForward;
  Timer? _doubleTapFeedbackTimer;
  DateTime? _lastEdgeTapAt;
  Offset? _lastEdgeTapPosition;
  Timer? _edgeTapTimer;
  bool _suppressNextEdgeTap = false;

  @override
  void initState() {
    super.initState();
    widget.playbackSpeedListenable.addListener(_handleSpeedChanged);
    _loading = widget.prepare;
    if (widget.active) unawaited(_initializeNowPlaying());
    if (widget.prepare) unawaited(_initializeWhenReady());
  }

  @override
  void didUpdateWidget(covariant _EpisodePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.prepare && widget.prepare) ||
        (!oldWidget.active && widget.active)) {
      unawaited(_initializeWhenReady());
    }
    if (oldWidget.speedLocked != widget.speedLocked) {
      _handleSpeedChanged();
    }
    if (oldWidget.active != widget.active) {
      if (oldWidget.active && !widget.active) {
        widget.onPlaybackStateChanged(false);
      }
      _syncPlaybackState();
      if (widget.active) unawaited(_initializeNowPlaying());
    }
    if (oldWidget.active != widget.active ||
        oldWidget.landscape != widget.landscape ||
        oldWidget.chromeVisible != widget.chromeVisible) {
      _scheduleChromeHide();
    }
  }

  bool get _showVideo => widget.active;

  void _scheduleChromeHide() {
    _chromeTimer?.cancel();
    if (!widget.active ||
        !widget.chromeVisible ||
        _controller?.isPlaying != true ||
        _scrubbing ||
        _seeking ||
        _horizontalSeeking ||
        _speedBoosting ||
        MediaQuery.accessibleNavigationOf(context) ||
        _pointersDown > 0) {
      return;
    }
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        widget.onHideChrome();
      }
    });
  }

  void _surfaceTap() {
    // Revealing a clear screen must not interrupt the video underneath it.
    if (!widget.chromeVisible) {
      widget.onShowChrome();
    } else if (widget.landscape) {
      widget.onHideChrome();
    } else {
      unawaited(_togglePlayback());
    }
  }

  void _surfaceTapUp(TapUpDetails details) {
    if (_suppressNextEdgeTap) {
      _suppressNextEdgeTap = false;
      return;
    }
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    if (width <= 0) {
      _surfaceTap();
      return;
    }
    final dx = details.localPosition.dx;
    final isEdge = dx < width * 0.25 || dx > width * 0.75;
    if (!isEdge) {
      _surfaceTap();
      return;
    }
    _edgeTapTimer?.cancel();
    _edgeTapTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _edgeTapTimer = null;
      _lastEdgeTapAt = null;
      _lastEdgeTapPosition = null;
      _surfaceTap();
    });
  }

  void _handlePointerUpForDoubleTap(PointerUpEvent event) {
    if (!widget.active) return;
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    if (width <= 0) return;
    final dx = event.localPosition.dx;
    final isLeft = dx < width * 0.25;
    final isRight = dx > width * 0.75;
    if (!isLeft && !isRight) return;
    final now = DateTime.now();
    final lastAt = _lastEdgeTapAt;
    final lastPosition = _lastEdgeTapPosition;
    if (lastAt != null &&
        lastPosition != null &&
        now.difference(lastAt) < const Duration(milliseconds: 300) &&
        (event.localPosition - lastPosition).distance < 44) {
      _lastEdgeTapAt = null;
      _lastEdgeTapPosition = null;
      _edgeTapTimer?.cancel();
      _edgeTapTimer = null;
      _suppressNextEdgeTap = true;
      unawaited(_handleDoubleTapAt(event.localPosition, isRight));
      return;
    }
    _lastEdgeTapAt = now;
    _lastEdgeTapPosition = event.localPosition;
  }

  Future<void> _handleDoubleTapAt(Offset position, bool forward) async {
    final controller = _controller;
    if (controller == null ||
        !controller.isReady ||
        _scrubbing ||
        _seeking ||
        _horizontalSeeking ||
        _speedBoosting ||
        controller.duration <= Duration.zero) {
      return;
    }
    const step = Duration(seconds: 10);
    final rawTarget = forward
        ? controller.position + step
        : controller.position - step;
    final target = Duration(
      milliseconds: rawTarget.inMilliseconds.clamp(
        0,
        controller.duration.inMilliseconds,
      ),
    );
    HapticFeedback.mediumImpact();
    final resume = controller.isPlaying;
    _doubleTapFeedbackTimer?.cancel();
    setState(() {
      _doubleTapForward = forward;
      _seeking = true;
      _scrubPosition = target;
    });
    _doubleTapFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _doubleTapForward = null);
    });
    _pauseForSeek = resume ? controller.pause() : null;
    await _commitSeek(controller, target, resume);
  }

  Future<void> _openEpisodes() async {
    _chromeTimer?.cancel();
    await widget.onOpenEpisodes();
    if (mounted) _scheduleChromeHide();
  }

  Future<void> _openComments() async {
    _chromeTimer?.cancel();
    await showCommentsSheet(
      context,
      videoId: widget.detail.id,
      episode: widget.episode.number,
      title: widget.detail.title,
      totalComments: widget.detail.commentCount,
    );
    if (mounted) _scheduleChromeHide();
  }

  Future<void> _initializeNowPlaying() async {
    await HgNowPlayingService.initialize(
      onPlay: () async {
        await _controller?.play();
        _emitProgress(force: true);
      },
      onPause: () async {
        await _controller?.pause();
        _emitProgress(force: true);
      },
      onToggle: () async {
        await _controller?.toggle();
        _emitProgress(force: true);
      },
      onSeek: (seconds) async {
        await _controller?.seekTo(
          Duration(milliseconds: (seconds * 1000).round()),
        );
        _emitProgress(force: true);
      },
    );
  }

  void _syncPlaybackState() {
    if (!_showVideo) _emitProgress(force: true, allowInactive: true);
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

  void _handleSpeedChanged() {
    final speed = widget.speedLocked
        ? 2.0
        : widget.playbackSpeedListenable.value;
    unawaited(_controller?.setPlaybackSpeed(speed));
  }

  void _handleControllerChanged() {
    final controller = _controller;
    if (controller != null && controller.hasError) {
      if (_lastPlaying != false) {
        _lastPlaying = false;
        if (widget.active) widget.onPlaybackStateChanged(false);
      }
      if (_initializing || _recovering) return;
      _recovering = true;
      // ChangeNotifier must finish notifying before its controller is disposed.
      scheduleMicrotask(() => _recoverPlayback(controller));
      return;
    }
    if (_lastPlaying != controller?.isPlaying) {
      _lastPlaying = controller?.isPlaying;
      if (widget.active) {
        widget.onPlaybackStateChanged(controller?.isPlaying ?? false);
      }
      _scheduleChromeHide();
    }
    final wideVideo = (controller?.aspectRatio ?? 0) > 1.2;
    if (wideVideo != _wideVideo && mounted) {
      setState(() => _wideVideo = wideVideo);
    }
    _emitProgress();
  }

  Future<void> _recoverPlayback(HgVideoController controller) async {
    try {
      if (!mounted || !identical(controller, _controller)) return;
      final message = _friendlyPlaybackError(
        controller.errorDescription ?? '视频源加载失败',
      );
      _recoveryPosition = controller.position;
      _controller = null;
      controller.removeListener(_handleControllerChanged);
      controller.dispose();
      setState(() {
        _loading = widget.active && _runtimeRetries == 0;
        _error = _loading ? null : message;
        _scrubbing = false;
        _seeking = false;
      });
      if (_loading) {
        _runtimeRetries++;
        await _initializePlayback();
      }
    } finally {
      _recovering = false;
    }
  }

  void _emitProgress({bool force = false, bool allowInactive = false}) {
    if ((!widget.active && !allowInactive) ||
        _scrubbing ||
        _seeking ||
        _horizontalSeeking) {
      return;
    }
    final controller = _controller;
    if (controller == null || !controller.isReady) return;
    final duration = controller.duration;
    if (duration <= Duration.zero) return;
    final now = DateTime.now();
    final last = _lastProgressAt;
    final progressDue =
        force ||
        last == null ||
        now.difference(last) >= const Duration(seconds: 5);
    if (progressDue) {
      _lastProgressAt = now;
      widget.onProgress(controller.position, duration);
    }
    if (!widget.active) return;
    final lastNowPlaying = _lastNowPlayingAt;
    if (force ||
        lastNowPlaying == null ||
        now.difference(lastNowPlaying) >= const Duration(seconds: 2)) {
      _lastNowPlayingAt = now;
      unawaited(
        HgNowPlayingService.update(
          title: widget.detail.title,
          subtitle: '第 ${widget.episode.number} 集 · 果幕',
          cover: widget.detail.cover,
          position: controller.position,
          duration: duration,
          isPlaying: controller.isPlaying,
          speed: widget.speedLocked || _speedBoosting
              ? 2
              : widget.playbackSpeedListenable.value,
          deepLink: 'guomu://video/${widget.detail.id}',
        ),
      );
    }
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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
          final resume =
              _recoveryPosition ??
              Duration(milliseconds: widget.resumePositionMs);
          if (resume > const Duration(seconds: 1) &&
              controller.duration >
                  resume + const Duration(milliseconds: 800)) {
            await controller.seekTo(resume);
          }
          await controller.setPlaybackSpeed(
            widget.speedLocked ? 2 : widget.playbackSpeedListenable.value,
          );
          if (!mounted) return;
          if (_showVideo) {
            await controller.play();
          } else {
            await controller.pause();
          }
          if (!mounted) return;
          if (controller.hasError) {
            throw StateError(controller.errorDescription ?? '视频加载失败');
          }
          setState(() => _loading = false);
          _emitProgress(force: true);
          return;
        } catch (error) {
          if (identical(_controller, controller)) {
            _controller = null;
            controller?.removeListener(_handleControllerChanged);
          }
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
    widget.playbackSpeedListenable.removeListener(_handleSpeedChanged);
    _chromeTimer?.cancel();
    _doubleTapFeedbackTimer?.cancel();
    _edgeTapTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      _emitProgress(force: true);
      controller.removeListener(_handleControllerChanged);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_scrubbing || _seeking || _horizontalSeeking) return;
    final controller = _controller;
    if (controller == null) {
      if (_error != null) {
        _runtimeRetries = 0;
        setState(() {
          _loading = true;
          _error = null;
        });
        await _initializePlayback();
      }
      return;
    }
    await controller.toggle();
    if (!mounted) return;
    widget.onShowChrome();
    _scheduleChromeHide();
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
    if (_seeking ||
        controller == null ||
        controller.duration <= Duration.zero) {
      return;
    }
    HapticFeedback.selectionClick();
    _resumeAfterScrub = controller.isPlaying;
    _pauseForSeek = _resumeAfterScrub ? controller.pause() : null;
    _chromeTimer?.cancel();
    setState(() {
      _scrubbing = true;
      _scrubPosition = _positionForFraction(fraction);
    });
  }

  void _updateScrubbing(double fraction) {
    if (!_scrubbing) return;
    setState(() => _scrubPosition = _positionForFraction(fraction));
  }

  void _finishScrubbing(double fraction) {
    final controller = _controller;
    if (controller == null || !_scrubbing) return;
    final target = _positionForFraction(fraction);
    setState(() {
      _scrubbing = false;
      _seeking = true;
      _scrubPosition = target;
    });
    unawaited(_commitSeek(controller, target, _resumeAfterScrub));
  }

  Future<void> _commitSeek(
    HgVideoController controller,
    Duration target,
    bool resume,
  ) async {
    try {
      await _pauseForSeek;
      await controller.seekTo(target);
    } catch (_) {
      if (mounted && widget.active) showHgSnack(context, '暂时无法跳转，请重试');
    }
    await _restoreAfterSeek(controller, resume);
  }

  Future<void> _restoreAfterSeek(
    HgVideoController controller,
    bool resume,
  ) async {
    if (!mounted || !identical(controller, _controller)) return;
    _pauseForSeek = null;
    try {
      if (widget.active && resume) await controller.play();
    } catch (_) {
      if (mounted && widget.active) showHgSnack(context, '请点击继续播放');
    } finally {
      if (mounted && identical(controller, _controller)) {
        setState(() => _seeking = false);
        _emitProgress(force: true);
        _scheduleChromeHide();
      }
    }
  }

  void _startHorizontalSeek(DragStartDetails details) {
    final controller = _controller;
    if (controller == null ||
        !widget.active ||
        !controller.isReady ||
        controller.duration <= Duration.zero ||
        _scrubbing ||
        _seeking ||
        _horizontalSeeking ||
        _speedBoosting) {
      return;
    }
    HapticFeedback.selectionClick();
    _horizontalSeekDelta = 0;
    _horizontalSeekStart = controller.position;
    _resumeAfterHorizontalSeek = controller.isPlaying;
    _chromeTimer?.cancel();
    setState(() {
      _horizontalSeeking = true;
      _scrubPosition = _horizontalSeekStart;
    });
    _pauseForSeek = _resumeAfterHorizontalSeek ? controller.pause() : null;
  }

  void _updateHorizontalSeek(DragUpdateDetails details) {
    final controller = _controller;
    if (!_horizontalSeeking || controller == null) return;
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    _horizontalSeekDelta += details.primaryDelta ?? 0;
    setState(() {
      _scrubPosition = hgHorizontalSeekTarget(
        start: _horizontalSeekStart,
        duration: controller.duration,
        deltaPixels: _horizontalSeekDelta,
        width: width,
      );
    });
  }

  void _finishHorizontalSeek(DragEndDetails details) {
    final controller = _controller;
    if (!_horizontalSeeking || controller == null) return;
    final target = _scrubPosition;
    final resume = _resumeAfterHorizontalSeek;
    HapticFeedback.selectionClick();
    setState(() {
      _horizontalSeeking = false;
      _seeking = true;
    });
    unawaited(_commitSeek(controller, target, resume));
  }

  Future<void> _cancelHorizontalSeek() async {
    if (!_horizontalSeeking) return;
    final controller = _controller;
    final resume = _resumeAfterHorizontalSeek;
    setState(() {
      _horizontalSeeking = false;
      _seeking = true;
    });
    try {
      await _pauseForSeek;
    } catch (_) {
      // A canceled gesture keeps its original position and playback intent.
    }
    if (controller != null) await _restoreAfterSeek(controller, resume);
  }

  Future<void> _startBoost(LongPressStartDetails details) async {
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final x = details.localPosition.dx;
    final onSide = x < width * 0.3 || x > width * 0.7;
    if (!onSide || _controller?.isPlaying != true) return;
    _chromeTimer?.cancel();
    setState(() {
      _speedBoosting = true;
      _speedLockInGesture = null;
    });
    await _controller?.setPlaybackSpeed(2);
  }

  void _moveBoost(LongPressMoveUpdateDetails details) {
    if (!_speedBoosting || _speedLockInGesture != null) return;
    if (!widget.speedLocked && details.offsetFromOrigin.dy < -46) {
      HapticFeedback.mediumImpact();
      setState(() => _speedLockInGesture = true);
      widget.onSpeedLockChanged(true);
      return;
    }
    if (widget.speedLocked && details.offsetFromOrigin.dy > 46) {
      HapticFeedback.mediumImpact();
      setState(() => _speedLockInGesture = false);
      widget.onSpeedLockChanged(false);
      unawaited(
        _controller?.setPlaybackSpeed(widget.playbackSpeedListenable.value),
      );
    }
  }

  Future<void> _endBoost() async {
    if (!_speedBoosting) return;
    if (!(_speedLockInGesture ?? widget.speedLocked)) {
      await _controller?.setPlaybackSpeed(widget.playbackSpeedListenable.value);
    }
    if (mounted) setState(() => _speedBoosting = false);
    if (mounted) _scheduleChromeHide();
  }

  Future<void> _toggleLike() async {
    try {
      await runAuthenticated(context, () async {
        HapticFeedback.lightImpact();
        await context.read<AuthController>().toggleLike(
          widget.detail.id,
          widget.episode.number,
        );
        return true;
      });
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      await runAuthenticated(context, () async {
        HapticFeedback.mediumImpact();
        await context.read<AuthController>().toggleFavorite(widget.detail.id);
        return true;
      });
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    }
  }

  Future<void> _enterLandscape() => HgPlayerDisplay.enterLandscape();

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setVolume(controller.volume > 0 ? 0 : 1);
    if (mounted) setState(() {});
    HapticFeedback.selectionClick();
  }

  Future<void> _share() async {
    _chromeTimer?.cancel();
    final url = '${resolveHgApiBaseUrl()}/video/${widget.detail.id}/';
    await showHgShareSheet(
      context,
      title: widget.detail.title,
      subtitle: '第 ${widget.episode.number} 集 · ${widget.detail.episodeLabel}',
      url: url,
    );
    if (mounted) _scheduleChromeHide();
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
    final safeLeft = MediaQuery.paddingOf(context).left;
    final safeRight = MediaQuery.paddingOf(context).right;
    return AnimatedOpacity(
      opacity: widget.chromeVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !widget.chromeVisible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(
              child: DecoratedBox(
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
            ),
            Positioned(
              top: top + 8,
              left: safeLeft + 12,
              right: safeRight + 12,
              child: Row(
                children: [
                  _VideoCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    label: '退出全屏',
                    onTap: () => unawaited(HgPlayerDisplay.exitLandscape()),
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
                    icon: Icons.playlist_play_rounded,
                    label: '选集',
                    onTap: _openEpisodes,
                  ),
                ],
              ),
            ),
            Positioned(
              left: safeLeft + 16,
              top: top + 68,
              child: _VideoCircleButton(
                label: _controller?.volume == 0 ? '取消静音' : '静音',
                icon: _controller != null && _controller!.volume <= 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                onTap: _toggleMute,
              ),
            ),
            if (_controller != null &&
                !_scrubbing &&
                !_seeking &&
                !_horizontalSeeking)
              Center(
                child: AnimatedBuilder(
                  animation: _controller!,
                  builder: (context, _) => Semantics(
                    button: true,
                    label: _controller!.isPlaying ? '暂停播放' : '继续播放',
                    child: GestureDetector(
                      key: const ValueKey('hg-landscape-play-button'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlayback,
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: Icon(
                          _controller!.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 48,
                          shadows: _kPlayerIconShadow,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: safeLeft + 12,
              right: safeRight + 12,
              bottom: 28 + bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller != null)
                    AnimatedBuilder(
                      animation: _controller!,
                      builder: (context, _) => HgPlayerSeekBar(
                        position: (_scrubbing || _seeking || _horizontalSeeking)
                            ? _scrubPosition
                            : _controller!.position,
                        duration: _controller!.duration,
                        scrubbing: _scrubbing,
                        seeking: _seeking || _horizontalSeeking,
                        buffered: _controller!.bufferedPosition,
                        showTimeLabels: true,
                        onScrubStart: _startScrubbing,
                        onScrubUpdate: _updateScrubbing,
                        onScrubEnd: _finishScrubbing,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _LandscapeAction(
                        semanticsLabel: favorite ? '取消追剧' : '追剧',
                        icon: favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: favorite ? HgColors.gold : Colors.white,
                        label: formatCount(widget.detail.collectCount),
                        onTap: _toggleFavorite,
                      ),
                      _LandscapeAction(
                        semanticsLabel: '评论',
                        icon: Icons.chat_bubble_outline_rounded,
                        label: formatCount(widget.detail.commentCount),
                        onTap: _openComments,
                      ),
                      _LandscapeAction(
                        semanticsLabel: liked ? '取消点赞' : '点赞',
                        icon: liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: liked ? HgColors.orange : Colors.white,
                        label: formatCount(widget.detail.likeCount),
                        onTap: _toggleLike,
                      ),
                      _LandscapeAction(
                        semanticsLabel: '分享',
                        icon: Icons.ios_share_rounded,
                        label: '分享',
                        onTap: _share,
                      ),
                      const Spacer(),
                      HgPressable(
                        onTap: widget.onCycleSpeed,
                        haptic: true,
                        semanticLabel:
                            '播放速度 ${_speedText(widget.speedLocked ? 2 : widget.playbackSpeedListenable.value)}',
                        pressedOpacity: 0.55,
                        child: SizedBox(
                          height: 48,
                          width: 48,
                          child: Center(
                            child: Text(
                              _speedText(
                                widget.speedLocked
                                    ? 2
                                    : widget.playbackSpeedListenable.value,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _VideoCircleButton(
                        icon: Icons.fullscreen_exit_rounded,
                        label: '退出全屏',
                        onTap: () => unawaited(HgPlayerDisplay.exitLandscape()),
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
    final isLandscape = widget.landscape;
    final isWideVideo = _wideVideo;
    return Listener(
      onPointerDown: (_) {
        _pointersDown++;
        _chromeTimer?.cancel();
      },
      onPointerUp: (event) {
        _handlePointerUpForDoubleTap(event);
        if (_pointersDown > 0) _pointersDown--;
        _scheduleChromeHide();
      },
      onPointerCancel: (_) {
        if (_pointersDown > 0) _pointersDown--;
        _scheduleChromeHide();
      },
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && widget.active)
              _controller!.buildView()
            else if (!isLandscape && !isWideVideo)
              HgCoverImage(
                url: widget.detail.cover,
                title: widget.detail.title,
              ),
            if (!isLandscape && widget.chromeVisible)
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
              ),
            Positioned.fill(
              child: Semantics(
                label: !widget.chromeVisible
                    ? '显示播放控件'
                    : (isLandscape ? '隐藏播放控件' : '视频画面，点按播放或暂停'),
                child: GestureDetector(
                  key: const ValueKey('hg-player-surface'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _surfaceTapUp,
                  onHorizontalDragStart: _startHorizontalSeek,
                  onHorizontalDragUpdate: _updateHorizontalSeek,
                  onHorizontalDragEnd: _finishHorizontalSeek,
                  onHorizontalDragCancel: _cancelHorizontalSeek,
                  onLongPressStart: _startBoost,
                  onLongPressMoveUpdate: _moveBoost,
                  onLongPressEnd: (_) => _endBoost(),
                  onLongPressCancel: () => _endBoost(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (!_loading && _error != null)
              Center(
                child: _InlinePlaybackError(
                  error: _error!,
                  onRetry: () {
                    _runtimeRetries = 0;
                    unawaited(_initializePlayback());
                  },
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
                          bottom: 170,
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
                          bottom: 170,
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
                              onComments: _openComments,
                              onFavorite: _toggleFavorite,
                              onShare: _share,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 8,
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_controller != null) ...[
                                  AnimatedBuilder(
                                    animation: _controller!,
                                    builder: (context, child) =>
                                        HgPlayerSeekBar(
                                          position:
                                              (_scrubbing ||
                                                  _seeking ||
                                                  _horizontalSeeking)
                                              ? _scrubPosition
                                              : _controller!.position,
                                          duration: _controller!.duration,
                                          scrubbing: _scrubbing,
                                          seeking:
                                              _seeking || _horizontalSeeking,
                                          buffered:
                                              _controller!.bufferedPosition,
                                          showTimeLabels: false,
                                          onScrubStart: _startScrubbing,
                                          onScrubUpdate: _updateScrubbing,
                                          onScrubEnd: _finishScrubbing,
                                        ),
                                  ),
                                  const SizedBox(height: 7),
                                ],
                                _WatchAllBar(
                                  label:
                                      '全 ${widget.detail.totalEpisodes > 0 ? widget.detail.totalEpisodes : (widget.detail.episodeCount > 0 ? widget.detail.episodeCount : widget.detail.episodes.length)} 集 · 当前第 ${widget.episode.number} 集',
                                  onTap: _openEpisodes,
                                ),
                              ],
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
            if (_controller != null && widget.active && !widget.chromeVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 2),
                    child: AnimatedBuilder(
                      animation: _controller!,
                      builder: (context, _) {
                        final duration = _controller!.duration;
                        final fraction = duration <= Duration.zero
                            ? 0.0
                            : (_controller!.position.inMilliseconds /
                                      duration.inMilliseconds)
                                  .clamp(0.0, 1.0);
                        return _HiddenPlayerProgress(fraction: fraction);
                      },
                    ),
                  ),
                ),
              ),
            if (_horizontalSeeking && _controller != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: _HorizontalSeekHud(
                      target: _scrubPosition,
                      total: _controller!.duration,
                      forward: _horizontalSeekDelta >= 0,
                      delta: Duration(
                        milliseconds:
                            _scrubPosition.inMilliseconds -
                            _horizontalSeekStart.inMilliseconds,
                      ),
                    ),
                  ),
                ),
              ),
            if (_doubleTapForward != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: _doubleTapForward!
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34),
                      child: _DoubleTapSeekHud(forward: _doubleTapForward!),
                    ),
                  ),
                ),
              ),
            if (_speedBoosting)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 70,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _SpeedLockHint(
                      locked: _speedLockInGesture ?? widget.speedLocked,
                    ),
                  ),
                ),
              ),
            if (!isLandscape && isWideVideo && widget.chromeVisible)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 58,
                right: 16,
                child: _LandscapeEntry(onTap: _enterLandscape),
              ),
            if (_controller != null && !_loading && widget.active)
              AnimatedBuilder(
                animation: _controller!,
                builder: (context, child) => HgPlaybackFeedback(
                  busy:
                      !_scrubbing &&
                      (_seeking ||
                          (!_horizontalSeeking &&
                              _controller!.isPlaying &&
                              _controller!.isBuffering)),
                  paused:
                      !isLandscape &&
                      !_controller!.isPlaying &&
                      !_scrubbing &&
                      !_seeking &&
                      !_horizontalSeeking,
                  onPlay: _togglePlayback,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackSpeedSheet extends StatelessWidget {
  const _PlaybackSpeedSheet({required this.current, required this.locked});

  final double current;
  final bool locked;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  String _label(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(2);
    return '${text}x';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '播放速度',
                style: TextStyle(
                  color: context.hgOnSurface,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: HgColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    '长按锁定 2x',
                    style: TextStyle(
                      color: HgColors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '选择适合你的节奏，长按画面两侧可临时 2 倍速。',
            style: TextStyle(
              color: context.hgMuted,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 9.0;
              final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final speed in _speeds)
                    SizedBox(
                      width: itemWidth,
                      height: 46,
                      child: Material(
                        color: (current - speed).abs() < 0.001
                            ? HgColors.orange
                            : context.hgSurfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: HgInkWell(
                          key: ValueKey<String>('hg-speed-${_label(speed)}'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).pop(speed);
                          },
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _label(speed),
                                  style: TextStyle(
                                    color: (current - speed).abs() < 0.001
                                        ? Colors.white
                                        : context.hgOnSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if ((current - speed).abs() < 0.001) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.swipe_up_alt_rounded,
                color: context.hgMuted,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '长按画面两侧后上滑锁定 2x，下滑解除。',
                  style: TextStyle(
                    color: context.hgMuted,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HiddenPlayerProgress extends StatelessWidget {
  const _HiddenPlayerProgress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('hg-hidden-progress'),
      height: 2.5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.white.withValues(alpha: 0.14)),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              heightFactor: 1,
              child: const ColoredBox(color: HgColors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoubleTapSeekHud extends StatelessWidget {
  const _DoubleTapSeekHud({required this.forward});

  final bool forward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            color: Colors.white,
            size: 21,
          ),
          const SizedBox(width: 7),
          Text(
            forward ? '+10 秒' : '-10 秒',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalSeekHud extends StatelessWidget {
  const _HorizontalSeekHud({
    required this.target,
    required this.total,
    required this.forward,
    required this.delta,
  });

  final Duration target;
  final Duration total;
  final bool forward;
  final Duration delta;

  @override
  Widget build(BuildContext context) {
    final seconds = (delta.inMilliseconds / 1000).round();
    final amount = '${seconds >= 0 ? '+' : '-'}${seconds.abs()} 秒';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatDuration(target.inSeconds)} / ${formatDuration(total.inSeconds)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

const List<Shadow> _kPlayerIconShadow = [
  Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 1)),
];
const List<Shadow> _kPlayerLabelShadow = [
  Shadow(color: Color(0x99000000), blurRadius: 7, offset: Offset(0, 1)),
];

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
          semanticsLabel: favorite ? '取消追剧' : '追剧',
          icon: favorite ? Icons.star_rounded : Icons.star_border_rounded,
          color: favorite ? HgColors.gold : Colors.white,
          label: formatCount(collectCount),
          onTap: onFavorite,
        ),
        _RailAction(
          semanticsLabel: '评论',
          icon: Icons.chat_bubble_rounded,
          label: formatCount(commentCount),
          onTap: onComments,
        ),
        _RailAction(
          semanticsLabel: liked ? '取消点赞' : '点赞',
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? HgColors.orange : Colors.white,
          label: formatCount(likeCount),
          onTap: onLike,
        ),
        _RailAction(
          icon: Icons.ios_share_rounded,
          semanticsLabel: '分享',
          label: '分享',
          onTap: onShare,
        ),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 336),
        child: HgPressable(
          onTap: onTap,
          haptic: true,
          semanticLabel: '打开选集，$label',
          pressedOpacity: 0.72,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.44),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.playlist_play_rounded,
                  color: HgColors.orange,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  '选集',
                  style: TextStyle(
                    color: HgColors.orange,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.72),
                  size: 19,
                ),
              ],
            ),
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
    required this.semanticsLabel,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: semanticsLabel,
      value: label == semanticsLabel ? null : label,
      onTap: onTap,
      excludeSemantics: true,
      child: HgPressable(
        onTap: onTap,
        haptic: false,
        button: false,
        pressedOpacity: 0.58,
        child: Padding(
          padding: const EdgeInsets.only(right: 18, top: 12, bottom: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 23, shadows: _kPlayerIconShadow),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  shadows: _kPlayerLabelShadow,
                ),
              ),
            ],
          ),
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
    return Material(
      color: Colors.black.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: HgInkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
              SizedBox(width: 5),
              Text(
                '全屏观看',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: semanticsLabel,
      value: label == semanticsLabel ? null : label,
      onTap: onTap,
      excludeSemantics: true,
      child: HgPressable(
        onTap: onTap,
        haptic: false,
        button: false,
        pressedOpacity: 0.55,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              SizedBox(
                width: 43,
                height: 43,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  switchInCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Icon(
                    icon,
                    key: ValueKey<IconData>(icon),
                    color: color,
                    size: 24,
                    shadows: _kPlayerIconShadow,
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
                  shadows: _kPlayerLabelShadow,
                ),
              ),
            ],
          ),
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
  const _VideoCircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HgPressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: label,
      pressedOpacity: 0.5,
      child: SizedBox(
        width: 48,
        height: 48,
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
