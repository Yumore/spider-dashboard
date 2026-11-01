import 'package:dashboard/features/live/twitch_media/twitch_vod_playback_page_state_stub.dart'
    if (dart.library.io) 'package:dashboard/features/live/twitch_media/twitch_vod_playback_page_state.dart';
import 'package:dashboard/features/live/twitch_media/twitch_public_video.dart';
import 'package:flutter/material.dart';

/// Twitch VOD playback with synchronized public chat replay.
class TwitchVodPlaybackPage extends StatefulWidget {
  const TwitchVodPlaybackPage({
    required this.video,
    required this.playbackUri,
    super.key,
  });

  final TwitchPublicVideo video;
  final Uri playbackUri;

  @override
  TwitchVodPlaybackPageState createState() => TwitchVodPlaybackPageState();
}
