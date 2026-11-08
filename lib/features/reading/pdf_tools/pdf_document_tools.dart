import 'package:dashboard/app/platform/app_platform.dart';
import 'package:dashboard/features/reading/pdf_tools/pdf_document_inspection.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf_document/pdf_document.dart' as document;
import 'package:pdf_graphics/pdf_graphics.dart' as graphics;

const int _maxTextPreviewCharacters = 50000;
const int _maxTextPreviewPages = 300;

class PdfDocumentTools {
  static const int _maxNativeSingleFileBytes = 100 * 1024 * 1024;
  static const int _maxWebSingleFileBytes = 24 * 1024 * 1024;
  static const int _maxNativeMergeBytes = 200 * 1024 * 1024;
  static const int _maxWebMergeBytes = 48 * 1024 * 1024;
  static const int maxMergeFileCount = 20;

  int get maxSingleFileBytes =>
      AppPlatform.isWeb ? _maxWebSingleFileBytes : _maxNativeSingleFileBytes;

  int get maxMergeBytes =>
      AppPlatform.isWeb ? _maxWebMergeBytes : _maxNativeMergeBytes;

  Future<PdfDocumentInspection> inspect(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxSingleFileBytes) {
      throw const FormatException('PDF 文件为空或超过当前平台的处理大小限制。');
    }
    final result = await compute(_inspectPdfDocument, bytes);
    return PdfDocumentInspection(
      pageCount: result['pageCount']! as int,
      title: result['title']! as String,
      author: result['author']! as String,
      textPreview: result['textPreview']! as String,
      truncated: result['truncated']! as bool,
    );
  }

  Future<Uint8List> merge(List<Uint8List> documents) async {
    if (documents.length < 2 || documents.length > maxMergeFileCount) {
      throw FormatException('请选择 2 到 $maxMergeFileCount 个 PDF 文件。');
    }
    final totalBytes = documents.fold<int>(
      0,
      (total, bytes) => total + bytes.length,
    );
    if (totalBytes > maxMergeBytes || documents.any((bytes) => bytes.isEmpty)) {
      throw const FormatException('PDF 文件为空或合并总大小超过当前平台的处理限制。');
    }
    return compute(_mergePdfDocuments, documents);
  }
}

Map<String, Object> _inspectPdfDocument(Uint8List bytes) {
  final pdf = document.PdfDocument.open(bytes);
  final info = pdf.info;
  final text = StringBuffer();
  var truncated = pdf.pageCount > _maxTextPreviewPages;
  final pageLimit = pdf.pageCount < _maxTextPreviewPages
      ? pdf.pageCount
      : _maxTextPreviewPages;

  for (var pageIndex = 0; pageIndex < pageLimit; pageIndex++) {
    final pageText = graphics.PdfTextExtractor.extract(pdf, pageIndex).text;
    final remaining = _maxTextPreviewCharacters - text.length;
    if (remaining <= 0) {
      truncated = true;
      break;
    }
    if (pageText.length > remaining) {
      text.write(pageText.substring(0, remaining));
      truncated = true;
      break;
    }
    text.write(pageText);
    if (pageIndex + 1 < pageLimit && text.length < _maxTextPreviewCharacters) {
      text.writeln();
    }
    if (text.length >= _maxTextPreviewCharacters) {
      truncated = true;
      break;
    }
  }

  return <String, Object>{
    'pageCount': pdf.pageCount,
    'title': info['Title'] ?? '',
    'author': info['Author'] ?? '',
    'textPreview': text.toString(),
    'truncated': truncated,
  };
}

Uint8List _mergePdfDocuments(List<Uint8List> documents) =>
    document.PdfMerger.merge(documents);
