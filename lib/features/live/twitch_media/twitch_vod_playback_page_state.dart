import 'dart:async';

import 'package:dashboard/features/live/twitch_media/twitch_public_media_client.dart';
import 'package:dashboard/features/live/twitch_media/twitch_vod_chat_message.dart';
import 'package:dashboard/features/live/twitch_media/twitch_vod_playback_page.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Owns one VOD player and the bounded comments fetched around its playhead.
class TwitchVodPlaybackPageState extends State<TwitchVodPlaybackPage>
    with WidgetsBindingObserver {
  final TwitchPublicMediaClient _client = TwitchPublicMediaClient();
  final Set<int> _loadedBuckets = {};
  final Map<String, TwitchVodChatMessage> _comments = {};
  Player? _player;
  VideoController? _video;
  StreamSubscription<Duration>? _positionSubscription;
  Duration _position = Duration.zero;
  bool _chatLoading = false;
  String? _chatError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      MediaKit.ensureInitialized();
      final player = Player();
      _player = player;
      _video = VideoController(player);
      _positionSubscription = player.stream.position.listen(_onPosition);
      await player.open(Media(widget.playbackUri.toString()));
      await _loadComments(0);
    } catch (error) {
      if (mounted) setState(() => _chatError = '播放或聊天记录加载失败：$error');
    }
    if (mounted) setState(() {});
  }

  void _onPosition(Duration value) {
    final previousSecond = _position.inSeconds;
    _position = value;
    final bucket = value.inSeconds ~/ 30;
    if (!_loadedBuckets.contains(bucket)) unawaited(_loadComments(bucket));
    if (mounted && value.inSeconds != previousSecond) setState(() {});
  }

  Future<void> _loadComments(int bucket) async {
    if (!_loadedBuckets.add(bucket)) return;
    final generation = _generation;
    if (mounted) {
      setState(() {
        _chatLoading = true;
        _chatError = null;
      });
    }
    try {
      final comments = await _client.vodComments(
        videoId: widget.video.id,
        offsetSeconds: bucket * 30,
      );
      if (!mounted || generation != _generation) return;
      for (final comment in comments) {
        _comments[comment.id] = comment;
      }
      if (_comments.length > 3000) {
        final oldest = _comments.values.toList()
          ..sort((a, b) => a.offsetSeconds.compareTo(b.offsetSeconds));
        for (final comment in oldest.take(_comments.length - 3000)) {
          _comments.remove(comment.id);
        }
      }
      setState(() => _chatLoading = false);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      _loadedBuckets.remove(bucket);
      setState(() {
        _chatLoading = false;
        _chatError = '$error';
      });
    }
  }

  List<TwitchVodChatMessage> get _visibleComments {
    final now = _position.inMilliseconds / 1000;
    final rows =
        _comments.values
            .where((comment) => comment.offsetSeconds <= now + 1)
            .toList()
          ..sort((a, b) => a.offsetSeconds.compareTo(b.offsetSeconds));
    return rows.length > 100 ? rows.sublist(rows.length - 100) : rows;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(_player?.pause());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_positionSubscription?.cancel());
    unawaited(_player?.dispose());
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = _visibleComments;
    return Scaffold(
      appBar: AppBar(title: Text(widget.video.title)),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _video == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Video(controller: _video!),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 54,
                        child: IgnorePointer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final comment
                                  in comments
                                      .where(
                                        (comment) =>
                                            comment.offsetSeconds >=
                                            _position.inSeconds - 8,
                                      )
                                      .take(5))
                                Text(
                                  '${comment.author}: ${comment.text}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          ListTile(
            title: const Text('同步聊天重播'),
            subtitle: Text(
              _chatError ??
                  (_chatLoading
                      ? '正在加载当前时间段的聊天…'
                      : '回放 ${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}'),
            ),
            trailing: IconButton(
              tooltip: '刷新聊天记录',
              onPressed: _chatLoading
                  ? null
                  : () {
                      final bucket = _position.inSeconds ~/ 30;
                      _loadedBuckets.remove(bucket);
                      unawaited(_loadComments(bucket));
                    },
              icon: const Icon(Icons.refresh),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: comments.isEmpty
                ? const Center(child: Text('当前时间段暂无公开聊天记录'))
                : ListView.builder(
                    reverse: true,
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[comments.length - index - 1];
                      return ListTile(
                        dense: true,
                        title: Text(
                          comment.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(comment.text),
                        trailing: Text('${comment.offsetSeconds.floor()}s'),
                        onTap: () => unawaited(
                          _player?.seek(
                            Duration(seconds: comment.offsetSeconds.floor()),
                          ),
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
