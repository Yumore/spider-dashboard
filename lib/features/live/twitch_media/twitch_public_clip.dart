/// Public Twitch clip metadata returned by the channel clips connection.
class TwitchPublicClip {
  const TwitchPublicClip({
    required this.slug,
    required this.title,
    required this.thumbnail,
    required this.duration,
  });

  final String slug;
  final String title;
  final String thumbnail;
  final double duration;

  factory TwitchPublicClip.fromJson(Map<String, Object?> json) =>
      TwitchPublicClip(
        slug: '${json['slug'] ?? ''}'.trim(),
        title: '${json['title'] ?? ''}'.trim(),
        thumbnail: '${json['thumbnailURL'] ?? ''}'.trim(),
        duration: double.tryParse('${json['durationSeconds'] ?? 0}') ?? 0,
      );
}
