import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha256.dart';

import 'hg_update_service.dart';

abstract final class HgUpdateDownload {
  static const _channel = MethodChannel('com.guomu.huangguo/update');

  static Future<String> download(
    HgReleaseAsset asset, {
    CancelToken? cancelToken,
    void Function(int, int)? onProgress,
    Dio? client,
    Directory? directory,
  }) async {
    if (!RegExp(
      r'^https://api\.github\.com/repos/DearLicy/guomu/releases/assets/\d+$',
      caseSensitive: false,
    ).hasMatch(asset.apiUrl)) {
      throw const HgUpdateException('安装包缺少有效的 GitHub API 下载地址，请稍后重新检查更新');
    }
    final root =
        directory ??
        Directory('${(await getTemporaryDirectory()).path}/guomu-updates');
    await root.create(recursive: true);
    final name = asset.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (!name.toLowerCase().endsWith('.apk')) {
      throw const HgUpdateException('安装包格式无效');
    }
    final target = File('${root.path}/$name');
    final partial = File('${target.path}.part');
    final dio =
        client ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 45),
          ),
        );
    try {
      final response = await dio.download(
        asset.apiUrl,
        partial.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) =>
            onProgress?.call(received, total > 0 ? total : asset.size),
        options: Options(
          headers: {
            'Accept': 'application/octet-stream',
            'X-GitHub-Api-Version': '2022-11-28',
          },
          followRedirects: true,
        ),
      );
      if (response.statusCode != 200 ||
          (asset.size > 0 && await partial.length() != asset.size)) {
        throw const HgUpdateException('安装包未完整下载，请重试');
      }
      final file = await partial.open();
      try {
        final signature = await file.read(4);
        if (signature.length != 4 ||
            signature[0] != 0x50 ||
            signature[1] != 0x4b ||
            signature[2] != 3 ||
            signature[3] != 4) {
          throw const HgUpdateException('下载内容不是有效安装包，请重试');
        }
      } finally {
        await file.close();
      }
      if (asset.digest.startsWith('sha256:')) {
        final digest = SHA256Digest();
        await for (final chunk in partial.openRead()) {
          final bytes = Uint8List.fromList(chunk);
          digest.update(bytes, 0, bytes.length);
        }
        final output = Uint8List(32);
        digest.doFinal(output, 0);
        final actual = output
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
        if (actual != asset.digest.substring(7).toLowerCase()) {
          throw const HgUpdateException('安装包校验失败，请重新下载');
        }
      }
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      await partial.rename(target.path);
      return target.path;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw const HgUpdateException('下载中断，请检查网络后重试');
    } finally {
      if (await partial.exists()) await partial.delete();
      if (client == null) dio.close();
    }
  }

  static Future<void> install(String path) async {
    final result = await _channel.invokeMethod<bool>('installApk', {
      'path': path,
    });
    if (result != true) throw const HgUpdateException('无法打开安装程序，请稍后重试');
  }
}
