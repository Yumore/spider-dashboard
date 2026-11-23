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

class HgDownloadProgressSnapshot {
  const HgDownloadProgressSnapshot({
    required this.receivedBytes,
    required this.totalBytes,
    required this.completedSegments,
    required this.totalSegments,
  });

  final int receivedBytes;
  final int totalBytes;
  final int completedSegments;
  final int totalSegments;

  double get fraction {
    if (totalBytes > 0 && receivedBytes <= totalBytes) {
      return (receivedBytes / totalBytes).clamp(0.0, 1.0);
    }
    if (totalSegments > 0) {
      return (completedSegments / totalSegments).clamp(0.0, 1.0);
    }
    return 0;
  }
}

typedef HgDownloadProgress = void Function(HgDownloadProgressSnapshot progress);

class _MediaSegment {
  const _MediaSegment({required this.url, required this.name});

  final String url;
  final String name;
}

/// 将 HLS 播放列表及其分片下载到应用私有目录，并把 URI 重写为本地相对路径。
/// 不依赖外部 ffmpeg，保留 HLS 的加密 key 与 init segment，播放器可直接读取本地 m3u8。
abstract final class HgHlsDownloader {
  static const int _defaultParallelSegments = 4;

  static Future<HgDownloadedPlaylist> download({
    required Dio dio,
    required String playlistUrl,
    required Directory directory,
    Map<String, String> headers = const {},
    int segmentLimit = 0,
    int parallelSegments = _defaultParallelSegments,
    HgDownloadProgress? onProgress,
  }) async {
    await directory.create(recursive: true);
    final directUri = Uri.tryParse(playlistUrl);
    if (directUri != null && directUri.path.toLowerCase().endsWith('.mp4')) {
      return _downloadDirectVideo(
        dio: dio,
        url: playlistUrl,
        directory: directory,
        headers: headers,
        onProgress: onProgress,
      );
    }

    var resolvedUrl = playlistUrl;
    var playlist = await _fetchText(dio, resolvedUrl, headers);
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
      playlist = await _fetchText(dio, resolvedUrl, headers);
    }

    final baseUri = Uri.parse(resolvedUrl);
    final output = <String>[];
    final segments = <_MediaSegment>[];
    var auxiliaryBytes = 0;
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
          auxiliaryBytes += await _downloadBytes(
            dio,
            keyUrl,
            headers,
            File('${directory.path}/$name'),
          );
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
          auxiliaryBytes += await _downloadBytes(
            dio,
            mapUrl,
            headers,
            File('${directory.path}/$name'),
          );
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
      output.add(name);
      segments.add(_MediaSegment(url: segmentUrl, name: name));
      segmentCount++;
    }

    final sizes = await _probeSegmentSizes(
      dio,
      segments.map((segment) => segment.url).toList(growable: false),
      headers,
    );
    final knownTotal = sizes.fold<int>(0, (sum, size) => sum + size);
    final totalBytes = auxiliaryBytes + knownTotal;
    var receivedBytes = auxiliaryBytes;
    var completedSegments = 0;
    var lastEmitAt = DateTime.fromMillisecondsSinceEpoch(0);

    void emit({bool force = false}) {
      if (onProgress == null) return;
      final now = DateTime.now();
      if (!force && now.difference(lastEmitAt).inMilliseconds < 180) return;
      lastEmitAt = now;
      onProgress(
        HgDownloadProgressSnapshot(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          completedSegments: completedSegments,
          totalSegments: segments.length,
        ),
      );
    }

    emit(force: true);
    Object? firstError;
    StackTrace? firstStackTrace;
    var nextIndex = 0;
    Future<void> worker() async {
      while (firstError == null) {
        if (nextIndex >= segments.length) return;
        final segment = segments[nextIndex++];
        try {
          final file = File('${directory.path}/${segment.name}');
          var segmentReceived = 0;
          await _downloadToFile(
            dio: dio,
            url: segment.url,
            file: file,
            headers: headers,
            onChunk: (received) {
              segmentReceived += received;
              receivedBytes += received;
              emit();
            },
            onRetry: () {
              receivedBytes -= segmentReceived;
              segmentReceived = 0;
            },
          );
          completedSegments++;
          emit(force: true);
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
    }

    final workers = segments.isEmpty
        ? 0
        : parallelSegments.clamp(1, segments.length).toInt();
    await Future.wait(List.generate(workers, (_) => worker()));
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
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
    emit(force: true);
    return HgDownloadedPlaylist(
      manifestPath: manifest.path,
      directory: directory.path,
      bytes: receivedBytes,
    );
  }

  static Future<HgDownloadedPlaylist> _downloadDirectVideo({
    required Dio dio,
    required String url,
    required Directory directory,
    required Map<String, String> headers,
    HgDownloadProgress? onProgress,
  }) async {
    final total = await _contentLength(dio, url, headers) ?? 0;
    var received = 0;
    final file = File('${directory.path}/video.mp4');
    await _downloadToFile(
      dio: dio,
      url: url,
      file: file,
      headers: headers,
      onChunk: (bytes) {
        received += bytes;
        onProgress?.call(
          HgDownloadProgressSnapshot(
            receivedBytes: received,
            totalBytes: total,
            completedSegments: 0,
            totalSegments: 1,
          ),
        );
      },
      onRetry: () => received = 0,
    );
    onProgress?.call(
      HgDownloadProgressSnapshot(
        receivedBytes: received,
        totalBytes: total > 0 ? total : received,
        completedSegments: 1,
        totalSegments: 1,
      ),
    );
    return HgDownloadedPlaylist(
      manifestPath: file.path,
      directory: directory.path,
      bytes: received,
    );
  }

  static Future<String> _fetchText(
    Dio dio,
    String url,
    Map<String, String> headers,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: true,
            headers: headers,
          ),
        );
        return response.data ?? '';
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 220 * (attempt + 1)),
          );
        }
      }
    }
    throw lastError ?? const FormatException('播放列表加载失败');
  }

  static Future<int> _downloadBytes(
    Dio dio,
    String url,
    Map<String, String> headers,
    File file,
  ) async {
    var received = 0;
    await _downloadToFile(
      dio: dio,
      url: url,
      file: file,
      headers: headers,
      onChunk: (bytes) => received += bytes,
      onRetry: () => received = 0,
    );
    return received;
  }

  static Future<void> _downloadToFile({
    required Dio dio,
    required String url,
    required File file,
    required Map<String, String> headers,
    required void Function(int bytes) onChunk,
    void Function()? onRetry,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      IOSink? sink;
      try {
        if (await file.exists()) await file.delete();
        final response = await dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: true,
            headers: headers,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 300,
          ),
        );
        final body = response.data;
        if (body == null) throw const FormatException('媒体分片为空');
        sink = file.openWrite();
        await for (final chunk in body.stream) {
          sink.add(chunk);
          onChunk(chunk.length);
        }
        await sink.flush();
        await sink.close();
        sink = null;
        return;
      } catch (error) {
        lastError = error;
        await sink?.close();
        if (await file.exists()) await file.delete();
        if (attempt < 2) {
          onRetry?.call();
          await Future<void>.delayed(
            Duration(milliseconds: 220 * (attempt + 1)),
          );
        }
      }
    }
    throw lastError ?? const FormatException('媒体分片下载失败');
  }

  static Future<List<int>> _probeSegmentSizes(
    Dio dio,
    List<String> urls,
    Map<String, String> headers,
  ) async {
    final sizes = List<int>.filled(urls.length, 0);
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < urls.length) {
        final index = nextIndex++;
        sizes[index] = await _contentLength(dio, urls[index], headers) ?? 0;
      }
    }

    final workers = urls.isEmpty ? 0 : 8.clamp(1, urls.length).toInt();
    await Future.wait(List.generate(workers, (_) => worker()));
    return sizes;
  }

  static Future<int?> _contentLength(
    Dio dio,
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final response = await dio.head<void>(
        url,
        options: Options(followRedirects: true, headers: headers),
      );
      final raw = response.headers.value(Headers.contentLengthHeader);
      return raw == null ? null : int.tryParse(raw);
    } catch (_) {
      return null;
    }
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
