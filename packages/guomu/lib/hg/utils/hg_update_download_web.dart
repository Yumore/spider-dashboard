import 'package:dio/dio.dart';
import 'hg_update_service.dart';

abstract final class HgUpdateDownload {
  static Future<String> download(
    HgReleaseAsset asset, {
    CancelToken? cancelToken,
    void Function(int, int)? onProgress,
  }) async => throw const HgUpdateException('请在 Android App 中下载更新');
  static Future<void> install(String path) async =>
      throw const HgUpdateException('请在 Android App 中安装更新');
}
