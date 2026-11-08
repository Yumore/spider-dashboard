class PdfDocumentInspection {
  const PdfDocumentInspection({
    required this.pageCount,
    required this.title,
    required this.author,
    required this.textPreview,
    required this.truncated,
  });

  final int pageCount;
  final String title;
  final String author;
  final String textPreview;
  final bool truncated;
}
