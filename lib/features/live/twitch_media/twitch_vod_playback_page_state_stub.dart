import 'package:dashboard/features/live/twitch_media/twitch_vod_playback_page.dart';
import 'package:flutter/material.dart';

/// Web fallback when the native media player isn't available.
class TwitchVodPlaybackPageState extends State<TwitchVodPlaybackPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.video.title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          '当前 Web 构建不包含原生 Twitch 播放器。\n\n${widget.playbackUri}',
        ),
      ),
    ),
  );
}
