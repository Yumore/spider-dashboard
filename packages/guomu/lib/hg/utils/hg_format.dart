import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;

String formatCount(int value) {
  if (value >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(value >= 1000000000 ? 0 : 1)}亿';
  }
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1)}万';
  }
  return '$value';
}

String formatDuration(num seconds) {
  final total = seconds.round().clamp(0, 359999);
  final minutes = total ~/ 60;
  final remain = total % 60;
  return '$minutes:${remain.toString().padLeft(2, '0')}';
}

String cleanError(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  return text.isEmpty ? '操作失败，请稍后重试' : text;
}

String stripHtml(String html) {
  if (html.trim().isEmpty) return '';
  final document = html_parser.parse(html);
  return (document.body?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> extractHtmlImages(String html) {
  if (html.trim().isEmpty) return const [];
  final document = html_parser.parse(html);
  return document
      .querySelectorAll('img')
      .map((element) => element.attributes['src']?.trim() ?? '')
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
}

Color colorFromHex(String value, {Color fallback = const Color(0xFFFF6B3D)}) {
  final clean = value.replaceFirst('#', '').trim();
  if (clean.length != 6 && clean.length != 8) return fallback;
  final parsed = int.tryParse(clean, radix: 16);
  if (parsed == null) return fallback;
  return Color(clean.length == 6 ? 0xFF000000 | parsed : parsed);
}

void showHgSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '等待网络';
  return '${formatBytes(bytesPerSecond)}/s';
}
