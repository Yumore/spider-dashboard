import 'dart:convert';

class HgDownloadedEpisode {
  const HgDownloadedEpisode({
    required this.number,
    required this.directory,
    required this.manifestPath,
    required this.bytes,
    required this.updatedAt,
  });

  final int number;
  final String directory;
  final String manifestPath;
  final int bytes;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
    'number': number,
    'directory': directory,
    'manifest_path': manifestPath,
    'bytes': bytes,
    'updated_at': updatedAt,
  };

  factory HgDownloadedEpisode.fromJson(Map<String, dynamic> json) {
    return HgDownloadedEpisode(
      number: (json['number'] as num?)?.toInt() ?? 0,
      directory: json['directory']?.toString() ?? '',
      manifestPath: json['manifest_path']?.toString() ?? '',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class HgDownloadTask {
  const HgDownloadTask({
    required this.videoId,
    required this.title,
    required this.cover,
    this.tags = const [],
    this.totalEpisodes = 0,
    this.episodes = const {},
    this.autoUpdate = true,
    this.tracking = true,
    this.state = '等待下载',
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSecond = 0,
    this.lastError = '',
    this.lastKnownEpisode = 0,
    this.updatedAt = '',
  });

  final int videoId;
  final String title;
  final String cover;
  final List<String> tags;
  final int totalEpisodes;
  final Map<int, HgDownloadedEpisode> episodes;
  final bool autoUpdate;
  final bool tracking;
  final String state;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final int speedBytesPerSecond;
  final String lastError;
  final int lastKnownEpisode;
  final String updatedAt;

  bool get isDownloading => state == '下载中' || state == '检查更新';
  bool get isComplete =>
      totalEpisodes > 0 && episodes.length >= totalEpisodes && !isDownloading;
  int get downloadedBytes =>
      episodes.values.fold(0, (total, episode) => total + episode.bytes);

  HgDownloadTask copyWith({
    String? title,
    String? cover,
    List<String>? tags,
    int? totalEpisodes,
    Map<int, HgDownloadedEpisode>? episodes,
    bool? autoUpdate,
    bool? tracking,
    String? state,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    int? speedBytesPerSecond,
    String? lastError,
    int? lastKnownEpisode,
    String? updatedAt,
  }) {
    return HgDownloadTask(
      videoId: videoId,
      title: title ?? this.title,
      cover: cover ?? this.cover,
      tags: tags ?? this.tags,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      episodes: episodes ?? this.episodes,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      tracking: tracking ?? this.tracking,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      lastError: lastError ?? this.lastError,
      lastKnownEpisode: lastKnownEpisode ?? this.lastKnownEpisode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'video_id': videoId,
    'title': title,
    'cover': cover,
    'tags': tags,
    'total_episodes': totalEpisodes,
    'episodes': {
      for (final entry in episodes.entries)
        '${entry.key}': entry.value.toJson(),
    },
    'auto_update': autoUpdate,
    'tracking': tracking,
    'state': state,
    'progress': progress,
    'received_bytes': receivedBytes,
    'total_bytes': totalBytes,
    'speed_bytes_per_second': speedBytesPerSecond,
    'last_error': lastError,
    'last_known_episode': lastKnownEpisode,
    'updated_at': updatedAt,
  };

  factory HgDownloadTask.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'];
    final episodes = <int, HgDownloadedEpisode>{};
    if (rawEpisodes is Map) {
      for (final entry in rawEpisodes.entries) {
        final number = int.tryParse(entry.key.toString());
        if (number == null || entry.value is! Map) continue;
        episodes[number] = HgDownloadedEpisode.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    final rawTags = json['tags'];
    return HgDownloadTask(
      videoId: (json['video_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      tags: rawTags is List
          ? rawTags.map((item) => item.toString()).toList(growable: false)
          : const [],
      totalEpisodes: (json['total_episodes'] as num?)?.toInt() ?? 0,
      episodes: episodes,
      autoUpdate: json['auto_update'] != false,
      tracking: json['tracking'] != false,
      state: json['state']?.toString() ?? '等待下载',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      receivedBytes: (json['received_bytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      speedBytesPerSecond:
          (json['speed_bytes_per_second'] as num?)?.toInt() ?? 0,
      lastError: json['last_error']?.toString() ?? '',
      lastKnownEpisode: (json['last_known_episode'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  static List<HgDownloadTask> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map(
            (item) => HgDownloadTask.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.videoId > 0)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
