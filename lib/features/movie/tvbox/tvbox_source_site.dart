/// A direct, searchable TVBox CMS JSON source.
class TvBoxSourceSite {
  const TvBoxSourceSite({
    required this.key,
    required this.name,
    required this.api,
  });

  final String key;
  final String name;
  final Uri api;
}
