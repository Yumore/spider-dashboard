/// A playable episode split from one TVBox CMS `vod_play_url` group.
class TvBoxVodEpisode {
  const TvBoxVodEpisode({
    required this.group,
    required this.name,
    required this.url,
  });

  final String group;
  final String name;
  final Uri url;

  static List<TvBoxVodEpisode> parseGroups({
    required String playFrom,
    required String playUrl,
    required Uri baseUri,
  }) {
    final groups = playFrom.split(r'$$$');
    final rows = playUrl.split(r'$$$');
    final episodes = <TvBoxVodEpisode>[];
    for (var groupIndex = 0; groupIndex < rows.length; groupIndex++) {
      final groupName =
          groupIndex < groups.length && groups[groupIndex].trim().isNotEmpty
          ? groups[groupIndex].trim()
          : '线路 ${groupIndex + 1}';
      for (final rawEpisode in rows[groupIndex].split('#')) {
        final separator = rawEpisode.indexOf(r'$');
        if (separator <= 0 || separator == rawEpisode.length - 1) continue;
        final episodeName = rawEpisode.substring(0, separator).trim();
        final parsedUri = Uri.tryParse(
          rawEpisode.substring(separator + 1).trim(),
        );
        final uri = parsedUri != null && !parsedUri.hasScheme
            ? baseUri.resolveUri(parsedUri)
            : parsedUri;
        if (episodeName.isEmpty ||
            uri == null ||
            !<String>{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
          continue;
        }
        episodes.add(
          TvBoxVodEpisode(group: groupName, name: episodeName, url: uri),
        );
      }
    }
    return episodes;
  }
}
