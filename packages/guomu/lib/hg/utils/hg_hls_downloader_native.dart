import 'dart:io';

import 'package:dio/dio.dart';

class HgDownloadedPlaylist {
  const HgDownloadedPlaylist({
    required this.manifestPath,
    required this.directory,
    required this.bytes,
  });

  final String manifestPath;
  final String directory;
  final int bytes;
}

typedef HgDownloadProgress = void Function(int bytes, int totalBytes);

/// 将 HLS 播放列表及其分片下载到应用私有目录，并把 URI 重写为本地相对路径。
/// 不依赖外部 ffmpeg，保留 HLS 的加密 key 与 init segment，播放器可直接读取本地 m3u8。
abstract final class HgHlsDownloader {
  static Future<HgDownloadedPlaylist> download({
    required Dio dio,
    required String playlistUrl,
    required Directory directory,
    Map<String, String> headers = const {},
    int segmentLimit = 0,
    HgDownloadProgress? onProgress,
  }) async {
    await directory.create(recursive: true);
    var totalBytes = 0;
    final directUri = Uri.tryParse(playlistUrl);
    if (directUri != null && directUri.path.toLowerCase().endsWith('.mp4')) {
      final response = await dio.get<List<int>>(
        playlistUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          headers: headers,
        ),
      );
      final bytes = response.data ?? const <int>[];
      final file = File('${directory.path}/video.mp4');
      await file.writeAsBytes(bytes, flush: true);
      totalBytes += bytes.length;
      onProgress?.call(totalBytes, totalBytes);
      return HgDownloadedPlaylist(
        manifestPath: file.path,
        directory: directory.path,
        bytes: totalBytes,
      );
    }

    Future<String> fetchText(String url) async {
      final response = await dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          headers: headers,
        ),
      );
      return response.data ?? '';
    }

    Future<String> downloadMedia(String url, String name) async {
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          headers: headers,
        ),
      );
      final bytes = response.data ?? const <int>[];
      final file = File('${directory.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      totalBytes += bytes.length;
      onProgress?.call(totalBytes, 0);
      return name;
    }

    var resolvedUrl = playlistUrl;
    var playlist = await fetchText(resolvedUrl);
    if (!playlist.contains('#EXTM3U')) {
      throw const FormatException('播放地址不是有效的 HLS 列表');
    }
    final seen = <String>{};

    // 适配 master playlist：选择带宽最高的 variant，最终写出的 index.m3u8 是媒体列表。
    while (playlist.contains('#EXT-X-STREAM-INF')) {
      final lines = playlist.split('\n');
      String? variant;
      var bestBandwidth = -1;
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index].trim();
        if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
        final bandwidth =
            int.tryParse(
              RegExp(r'BANDWIDTH=(\d+)').firstMatch(line)?.group(1) ?? '',
            ) ??
            0;
        var cursor = index + 1;
        while (cursor < lines.length) {
          final candidate = lines[cursor].trim();
          if (candidate.isNotEmpty && !candidate.startsWith('#')) {
            if (bandwidth >= bestBandwidth) {
              bestBandwidth = bandwidth;
              variant = candidate;
            }
            break;
          }
          cursor++;
        }
      }
      if (variant == null || !seen.add(variant)) break;
      resolvedUrl = Uri.parse(resolvedUrl).resolve(variant).toString();
      playlist = await fetchText(resolvedUrl);
    }

    final baseUri = Uri.parse(resolvedUrl);
    final output = <String>[];
    var segmentCount = 0;
    var keyIndex = 0;
    var initIndex = 0;

    for (final rawLine in playlist.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        output.add('');
        continue;
      }
      if (trimmed.startsWith('#EXT-X-KEY')) {
        final uri = _firstUri(trimmed);
        if (uri != null && uri.isNotEmpty) {
          final keyUrl = baseUri.resolve(uri).toString();
          final name = 'key_${keyIndex++}.key';
          await downloadMedia(keyUrl, name);
          output.add(trimmed.replaceFirst(uri, name));
        } else {
          output.add(line);
        }
        continue;
      }
      if (trimmed.startsWith('#EXT-X-MAP')) {
        final uri = _firstUri(trimmed);
        if (uri != null && uri.isNotEmpty) {
          final mapUrl = baseUri.resolve(uri).toString();
          final name = 'init_${initIndex++}.mp4';
          await downloadMedia(mapUrl, name);
          output.add(trimmed.replaceFirst(uri, name));
        } else {
          output.add(line);
        }
        continue;
      }
      if (trimmed.startsWith('#')) {
        output.add(line);
        continue;
      }
      if (segmentLimit > 0 && segmentCount >= segmentLimit) {
        continue;
      }
      final segmentUrl = baseUri.resolve(trimmed).toString();
      final suffix = _suffixFor(segmentUrl);
      final name = 'seg_${segmentCount.toString().padLeft(5, '0')}$suffix';
      await downloadMedia(segmentUrl, name);
      output.add(name);
      segmentCount++;
    }

    if (segmentLimit > 0) {
      output.removeWhere((line) => line.trim() == '#EXT-X-ENDLIST');
      output.add('#EXT-X-ENDLIST');
    }
    if (!output.any((line) => line.trim().startsWith('#EXT-X-ENDLIST'))) {
      output.add('#EXT-X-ENDLIST');
    }
    final manifest = File('${directory.path}/index.m3u8');
    await manifest.writeAsString(output.join('\n'), flush: true);
    return HgDownloadedPlaylist(
      manifestPath: manifest.path,
      directory: directory.path,
      bytes: totalBytes,
    );
  }

  static String? _firstUri(String line) {
    return RegExp(r'''URI="([^"]+)"''').firstMatch(line)?.group(1);
  }

  static String _suffixFor(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m4s')) return '.m4s';
    if (path.endsWith('.mp4')) return '.mp4';
    if (path.endsWith('.aac')) return '.aac';
    return '.ts';
  }
}
