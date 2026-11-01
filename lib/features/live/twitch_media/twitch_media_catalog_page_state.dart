import 'dart:async';

import 'package:dashboard/features/live/twitch_media/twitch_media_catalog_page.dart';
import 'package:dashboard/features/live/twitch_media/twitch_public_clip.dart';
import 'package:dashboard/features/live/twitch_media/twitch_public_media_client.dart';
import 'package:dashboard/features/live/twitch_media/twitch_public_video.dart';
import 'package:dashboard/features/live/twitch_media/twitch_vod_playback_page.dart';
import 'package:dashboard/features/media/media_playback_page.dart';
import 'package:dashboard/features/media/media_stream_source.dart';
import 'package:flutter/material.dart';

/// Owns Twitch channel lookup and public archive/clip playback requests.
class TwitchMediaCatalogPageState extends State<TwitchMediaCatalogPage>
    with SingleTickerProviderStateMixin {
  final TwitchPublicMediaClient _client = TwitchPublicMediaClient();
  final TextEditingController _login = TextEditingController();
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTabChanged);
  String? _userId;
  String _channelName = '';
  List<TwitchPublicVideo> _videos = const [];
  List<TwitchPublicClip> _clips = const [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  void _onTabChanged() {
    if (!_tabs.indexIsChanging && _userId != null) unawaited(_loadMedia());
  }

  Future<void> _loadChannel() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _videos = const [];
      _clips = const [];
    });
    try {
      final channel = await _client.channel(_login.text);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _userId = channel.id;
        _channelName = channel.name;
      });
      await _loadMedia();
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _loadMedia() async {
    final userId = _userId;
    if (userId == null) return;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_tabs.index == 0) {
        final videos = await _client.videos(userId);
        if (mounted && requestId == _requestId) {
          setState(() {
            _videos = videos;
            _loading = false;
          });
        }
      } else {
        final clips = await _client.clips(userId);
        if (mounted && requestId == _requestId) {
          setState(() {
            _clips = clips;
            _loading = false;
          });
        }
      }
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _playVideo(TwitchPublicVideo video) async {
    try {
      final uri = await _client.vodPlaylist(video.id);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TwitchVodPlaybackPage(video: video, playbackUri: uri),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _playClip(TwitchPublicClip clip) async {
    try {
      final uri = await _client.clipPlayback(clip.slug);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MediaPlaybackPage(
            title: clip.title,
            sources: [MediaStreamSource(label: 'Twitch Clip', url: uri)],
            historyId: 'twitch-clip:${clip.slug}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  String _duration(int seconds) =>
      '${seconds ~/ 3600 > 0 ? '${seconds ~/ 3600}:' : ''}${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _requestId++;
    _client.dispose();
    _login.dispose();
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Twitch 回看与片段'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: '回放'),
          Tab(text: 'Clip 片段'),
        ],
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _login,
          decoration: InputDecoration(
            labelText: 'Twitch 频道名',
            hintText: 'channel_login',
            suffixIcon: IconButton(
              onPressed: _loading ? null : _loadChannel,
              icon: const Icon(Icons.search),
            ),
          ),
          onSubmitted: (_) => _loadChannel(),
        ),
        if (_channelName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _channelName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!_loading && _userId != null && _tabs.index == 0)
          for (final video in _videos)
            Card(
              child: ListTile(
                leading: video.thumbnail.isEmpty
                    ? const Icon(Icons.video_library_outlined)
                    : Image.network(
                        video.thumbnail
                            .replaceAll('{width}', '440')
                            .replaceAll('{height}', '248'),
                        width: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.video_library_outlined),
                      ),
                title: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_duration(video.duration)} · ${video.views} 次观看',
                ),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => _playVideo(video),
              ),
            ),
        if (!_loading && _userId != null && _tabs.index == 1)
          for (final clip in _clips)
            Card(
              child: ListTile(
                leading: clip.thumbnail.isEmpty
                    ? const Icon(Icons.video_library_outlined)
                    : Image.network(
                        clip.thumbnail,
                        width: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.video_library_outlined),
                      ),
                title: Text(
                  clip.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${clip.duration.toStringAsFixed(1)} 秒 · ${clip.slug}',
                ),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => _playClip(clip),
              ),
            ),
        if (!_loading &&
            _userId != null &&
            (_tabs.index == 0 ? _videos.isEmpty : _clips.isEmpty) &&
            _error == null)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('该频道暂时没有公开内容。'),
          ),
      ],
    ),
  );
}
