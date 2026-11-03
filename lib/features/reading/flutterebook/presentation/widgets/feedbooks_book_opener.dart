import 'dart:io';

import 'package:dashboard/features/reading/local_library/local_reading_record.dart';
import 'package:url_launcher/url_launcher.dart';

/// Feedbooks 下载文件的存在性检查与外部打开兼容入口。
///
/// Dashboard 的 Feedbooks 页面直接使用本地 Papyrus 阅读器；[openFile]
/// 保留为需要外部应用的调用方兼容入口。
///
/// 做成可注入的类（同 `YyetsLinkLauncher` 的写法）：widget 测试塞一个记录型
/// 假实现，不必真的拉起外部应用。
class FeedbooksBookOpener {
  const FeedbooksBookOpener({this.fileExists, this.launch});

  /// 测试注入点：给定时替代 `File(path).exists()`。
  final Future<bool> Function(String path)? fileExists;

  /// 测试注入点：给定时替代 `launchUrl`。
  final Future<bool> Function(Uri uri)? launch;

  /// 源工程 `openBook` 里文件缺失时的提示文案。
  static const String missingFileMessage =
      'Could not find the book file. Please download it again.';

  /// 文件在但没能唤起外部应用时的提示文案（源工程没有这条路径）。
  static const String openFailedMessage = 'Could not open the book file.';

  static LocalReadingRecord readingRecord({
    required String id,
    required String name,
    required String path,
  }) => LocalReadingRecord(
    id: 'feedbooks-$id',
    name: name,
    path: path,
    format: 'epub',
    sizeBytes: 0,
    importedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Future<bool> exists(String path) async {
    if (path.trim().isEmpty) return false;
    final Future<bool> Function(String path)? impl = fileExists;
    if (impl != null) return impl(path);
    try {
      return await File(path).exists();
    } on Exception {
      return false;
    }
  }

  Future<bool> openFile(String path) async {
    if (path.trim().isEmpty) return false;
    final Uri uri = Uri.file(path);
    final Future<bool> Function(Uri uri)? handler = launch;
    try {
      if (handler != null) return await handler(uri);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
