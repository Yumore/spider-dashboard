/// Public Twitch archive metadata returned by the channel videos connection.
class TwitchPublicVideo {
  const TwitchPublicVideo({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.views,
    required this.duration,
  });

  final String id;
  final String title;
  final String thumbnail;
  final int views;
  final int duration;

  factory TwitchPublicVideo.fromJson(Map<String, Object?> json) =>
      TwitchPublicVideo(
        id: '${json['id'] ?? ''}'.trim(),
        title: '${json['title'] ?? ''}'.trim(),
        thumbnail: '${json['previewThumbnailURL'] ?? ''}'.trim(),
        views: int.tryParse('${json['viewCount'] ?? 0}') ?? 0,
        duration: int.tryParse('${json['lengthSeconds'] ?? 0}') ?? 0,
      );
}
