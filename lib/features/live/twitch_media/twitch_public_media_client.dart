import 'dart:math';

import 'package:dashboard/features/live/twitch_media/twitch_public_clip.dart';
import 'package:dashboard/features/live/twitch_media/twitch_vod_chat_message.dart';
import 'package:dashboard/features/live/twitch_media/twitch_public_video.dart';
import 'package:dio/dio.dart';

/// Anonymous Twitch GraphQL discovery and signed VOD/Clip playback adapter.
class TwitchPublicMediaClient {
  TwitchPublicMediaClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {'Accept': 'application/json'},
            ),
          ),
      _deviceId = _newDeviceId();

  static const String _endpoint = 'https://gql.twitch.tv/gql';
  static const String _clientId = 'kd1unb4b3q4t58fwlpcbzcbnm76a8fp';
  final Dio _dio;
  final String _deviceId;

  Future<({String id, String name})> channel(String login) async {
    final cleanLogin = login.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{1,25}$').hasMatch(cleanLogin)) {
      throw const FormatException('请输入有效的 Twitch 频道名');
    }
    final data = await _request(
      operationName: 'DashboardTwitchChannel',
      query: r'''query DashboardTwitchChannel($login: String!) {
        user(login: $login) { id displayName }
      }''',
      variables: {'login': cleanLogin},
    );
    final user = data['user'];
    if (user is! Map) throw const FormatException('没有找到该 Twitch 频道');
    final id = '${user['id'] ?? ''}'.trim();
    if (id.isEmpty) throw const FormatException('Twitch 没有返回频道 ID');
    return (id: id, name: '${user['displayName'] ?? cleanLogin}');
  }

  Future<List<TwitchPublicVideo>> videos(String userId) async {
    final data = await _request(
      operationName: 'DashboardTwitchChannelVideos',
      query:
          r'''query DashboardTwitchChannelVideos($id: ID!, $first: Int!, $after: Cursor, $type: BroadcastType) {
        user(id: $id) {
          videos(first: $first, after: $after, type: $type, sort: TIME) {
            edges { node { id title lengthSeconds viewCount previewThumbnailURL(width: 440, height: 248) } }
          }
        }
      }''',
      variables: {'id': userId, 'first': 30, 'after': null, 'type': 'ARCHIVE'},
    );
    final connection = (data['user'] as Map?)?['videos'];
    final edges = (connection as Map?)?['edges'];
    if (edges is! List) return const [];
    return edges
        .map((edge) => (edge as Map?)?['node'])
        .whereType<Map>()
        .map(
          (node) => TwitchPublicVideo.fromJson(
            node.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((video) => video.id.isNotEmpty && video.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<TwitchPublicClip>> clips(String userId) async {
    final data = await _request(
      operationName: 'DashboardTwitchChannelClips',
      query:
          r'''query DashboardTwitchChannelClips($id: ID!, $first: Int!, $after: Cursor) {
        user(id: $id) {
          clips(first: $first, after: $after, criteria: {period: ALL_TIME}) {
            edges { node { slug title durationSeconds thumbnailURL } }
          }
        }
      }''',
      variables: {'id': userId, 'first': 30, 'after': null},
    );
    final connection = (data['user'] as Map?)?['clips'];
    final edges = (connection as Map?)?['edges'];
    if (edges is! List) return const [];
    return edges
        .map((edge) => (edge as Map?)?['node'])
        .whereType<Map>()
        .map(
          (node) => TwitchPublicClip.fromJson(
            node.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((clip) => clip.slug.isNotEmpty && clip.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<Uri> vodPlaylist(String videoId) async {
    if (!RegExp(r'^\d+$').hasMatch(videoId)) {
      throw const FormatException('Twitch VOD ID 格式无效');
    }
    final data = await _request(
      operationName: 'DashboardTwitchVodPlaybackToken',
      query: r'''query DashboardTwitchVodPlaybackToken($id: ID!) {
        videoPlaybackAccessToken(id: $id, params: {platform: "web", playerBackend: "mediaplayer", playerType: "site"}) {
          value signature
        }
      }''',
      variables: {'id': videoId},
    );
    final token = data['videoPlaybackAccessToken'];
    if (token is! Map) throw const FormatException('Twitch 没有返回 VOD 播放令牌');
    final value = '${token['value'] ?? ''}';
    final signature = '${token['signature'] ?? ''}';
    if (value.isEmpty || signature.isEmpty) {
      throw const FormatException('Twitch VOD 播放令牌无效');
    }
    return Uri.https('usher.ttvnw.net', '/vod/$videoId', {
      'platform': 'web',
      'player_type': 'site',
      'player_backend': 'mediaplayer',
      'client_id': _clientId,
      'nauth': value,
      'nauthsig': signature,
      'allow_source': 'true',
      'allow_audio_only': 'true',
      'playlist_include_framerate': 'true',
      'reassignments_supported': 'true',
      'supported_codecs': 'av1,h264,h265',
    });
  }

  Future<Uri> clipPlayback(String slug) async {
    final data = await _request(
      operationName: 'VideoAccessToken_Clip',
      query: r'''query VideoAccessToken_Clip($slug: ID!) {
        clip(slug: $slug) {
          playbackAccessToken(params: {platform: "web", playerBackend: "mediaplayer", playerType: "site"}) { value signature }
          videoQualities { frameRate quality sourceURL }
        }
      }''',
      variables: {'slug': slug},
    );
    final clip = data['clip'];
    if (clip is! Map) throw const FormatException('Twitch 没有返回 Clip 播放信息');
    final token = clip['playbackAccessToken'];
    final qualities = clip['videoQualities'];
    if (token is! Map || qualities is! List || qualities.isEmpty) {
      throw const FormatException('Twitch Clip 缺少播放线路');
    }
    final value = '${token['value'] ?? ''}';
    final signature = '${token['signature'] ?? ''}';
    final candidates = qualities.whereType<Map>().toList()
      ..sort(
        (a, b) => (int.tryParse('${b['quality']}') ?? 0).compareTo(
          int.tryParse('${a['quality']}') ?? 0,
        ),
      );
    for (final quality in candidates) {
      final raw = '${quality['sourceURL'] ?? ''}'.trim();
      final source = Uri.tryParse(raw);
      if (source == null ||
          source.scheme != 'https' ||
          !(source.host == 'twitch.tv' || source.host.endsWith('.twitch.tv'))) {
        continue;
      }
      return source.replace(
        queryParameters: {
          ...source.queryParameters,
          'sig': signature,
          'token': value,
        },
      );
    }
    throw const FormatException('Twitch Clip 没有可用的 HTTPS 播放线路');
  }

  Future<List<TwitchVodChatMessage>> vodComments({
    required String videoId,
    required double offsetSeconds,
  }) async {
    final response = await _dio.post<Object?>(
      _endpoint,
      data: {
        'operationName': 'VideoCommentsByOffsetOrCursor',
        'variables': {
          'videoID': videoId,
          'contentOffsetSeconds': offsetSeconds
              .clamp(0, double.infinity)
              .floor(),
        },
        'extensions': const {
          'persistedQuery': {
            'version': 1,
            'sha256Hash':
                'b70a3591ff0f4e0313d126c6a1502d79a1c02baebb288227c582044aa76adf6a',
          },
        },
      },
      options: Options(
        headers: {
          'Client-ID': 'kimne78kx3ncx6brgo4mv6wki5h1ko',
          'Client-Session-Id': _deviceId,
          'X-Device-Id': _deviceId,
          'Origin': 'https://www.twitch.tv',
          'Referer': 'https://www.twitch.tv/',
        },
      ),
    );
    final root = response.data;
    final data = (root as Map?)?['data'];
    final video = (data as Map?)?['video'];
    final comments = (video as Map?)?['comments'];
    final edges = (comments as Map?)?['edges'];
    if (edges is! List) return const [];
    return edges
        .map((edge) => (edge as Map?)?['node'])
        .whereType<Map>()
        .map(
          (node) => TwitchVodChatMessage.fromJson(
            node.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((comment) => comment.text.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, Object?>> _request({
    required String operationName,
    required String query,
    required Map<String, Object?> variables,
  }) async {
    final response = await _dio.post<Object?>(
      _endpoint,
      data: {
        'operationName': operationName,
        'query': query,
        'variables': variables,
      },
      options: Options(
        headers: {
          'Client-ID': _clientId,
          'X-Device-ID': _deviceId,
          'Content-Type': 'application/json',
          'Origin': 'https://www.twitch.tv',
          'Referer': 'https://www.twitch.tv/',
        },
      ),
    );
    final body = response.data;
    if (body is! Map) throw const FormatException('Twitch 响应格式错误');
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      throw FormatException(
        'Twitch 请求失败：${first is Map ? first['message'] : first}',
      );
    }
    final data = body['data'];
    if (data is! Map) throw const FormatException('Twitch 响应缺少 data');
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _newDeviceId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void dispose() => _dio.close();
}
