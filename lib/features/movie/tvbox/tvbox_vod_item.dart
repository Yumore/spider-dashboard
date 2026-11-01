import 'package:dashboard/features/movie/tvbox/tvbox_vod_episode.dart';

/// Search or detail record returned by a TVBox CMS JSON API.
class TvBoxVodItem {
  const TvBoxVodItem({
    required this.id,
    required this.title,
    required this.api,
    this.poster,
    this.remark = '',
    this.year = '',
    this.description = '',
    this.playFrom = '',
    this.playUrl = '',
  });

  final String id;
  final String title;
  final Uri api;
  final Uri? poster;
  final String remark;
  final String year;
  final String description;
  final String playFrom;
  final String playUrl;

  factory TvBoxVodItem.fromJson(Map<String, Object?> json, Uri api) {
    final parsedPoster = Uri.tryParse('${json['vod_pic'] ?? ''}'.trim());
    final poster = parsedPoster != null && !parsedPoster.hasScheme
        ? api.resolveUri(parsedPoster)
        : parsedPoster;
    return TvBoxVodItem(
      id: '${json['vod_id'] ?? json['id'] ?? ''}'.trim(),
      title: '${json['vod_name'] ?? json['name'] ?? ''}'.trim(),
      api: api,
      poster:
          poster != null &&
              <String>{'http', 'https'}.contains(poster.scheme.toLowerCase())
          ? poster
          : null,
      remark: '${json['vod_remarks'] ?? json['vod_remarks_en'] ?? ''}'.trim(),
      year: '${json['vod_year'] ?? ''}'.trim(),
      description: '${json['vod_content'] ?? json['vod_blurb'] ?? ''}'.trim(),
      playFrom: '${json['vod_play_from'] ?? ''}',
      playUrl: '${json['vod_play_url'] ?? ''}',
    );
  }

  List<TvBoxVodEpisode> get episodes => TvBoxVodEpisode.parseGroups(
    playFrom: playFrom,
    playUrl: playUrl,
    baseUri: api,
  );
}
