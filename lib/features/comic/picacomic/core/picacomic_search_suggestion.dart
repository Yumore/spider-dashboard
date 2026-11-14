/// A tag completion presented by the PicaComic search field.
class PicacomicSearchSuggestion {
  const PicacomicSearchSuggestion({required this.query, required this.label});

  /// Full query to place in the search field when selected.
  final String query;

  /// Localized tag label shown in the completion menu.
  final String label;
}
