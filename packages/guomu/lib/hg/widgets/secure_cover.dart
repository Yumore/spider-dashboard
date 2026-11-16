import 'dart:collection';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../api/hg_api.dart';
import '../theme/hg_theme.dart';
import 'hg_cover_crypto.dart' as cover_crypto;

class HgCoverCrypto {
  const HgCoverCrypto._();

  static Future<Uint8List> decryptOrPassThrough(Uint8List input) =>
      cover_crypto.decryptCover(input);
}

class HgCoverRepository {
  HgCoverRepository._();

  static final HgCoverRepository instance = HgCoverRepository._();
  static const int _cacheLimit = 160;
  static const int _maxConcurrent = 6;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      responseType: ResponseType.bytes,
      headers: hgMediaHeaders(),
    ),
  );
  final LinkedHashMap<String, Future<Uint8List>> _cache = LinkedHashMap();
  final List<Completer<void>> _waiters = [];
  int _activeDownloads = 0;

  Future<void> prefetch(Iterable<String> urls, {int limit = 10}) async {
    final queue = urls.where((url) => url.isNotEmpty).take(limit).toSet();
    final items = queue.toList(growable: false);
    for (var index = 0; index < items.length; index += _maxConcurrent) {
      await Future.wait(
        items
            .skip(index)
            .take(_maxConcurrent)
            .map((url) => load(url).then<void>((_) {}, onError: (Object _) {})),
      );
    }
  }

  Future<Uint8List> load(String url) {
    final cached = _cache.remove(url);
    if (cached != null) {
      _cache[url] = cached;
      return cached;
    }
    final future = _download(url).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _cache.remove(url);
      Error.throwWithStackTrace(error, stackTrace);
    });
    _cache[url] = future;
    while (_cache.length > _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  Future<Uint8List> _download(String url) async {
    await _acquireSlot();
    try {
      Object? lastError;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final response = await _dio.get<List<int>>(
            url,
            options: Options(
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 300,
            ),
          );
          final bytes = response.data;
          if (bytes == null || bytes.isEmpty) {
            throw const HgApiException('封面加载失败');
          }
          return await HgCoverCrypto.decryptOrPassThrough(
            Uint8List.fromList(bytes),
          );
        } catch (error) {
          lastError = error;
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 180 * (attempt + 1)),
            );
          }
        }
      }
      throw lastError ?? const HgApiException('封面加载失败');
    } finally {
      _releaseSlot();
    }
  }

  Future<void> _acquireSlot() async {
    if (_activeDownloads < _maxConcurrent) {
      _activeDownloads++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  void _releaseSlot() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _activeDownloads--;
    }
  }

  void clear() {
    _cache.clear();
  }
}

class HgCoverImage extends StatelessWidget {
  const HgCoverImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.title = '',
    this.borderRadius = BorderRadius.zero,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final String title;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: width,
      height: height,
      child: url.isEmpty
          ? _CoverPlaceholder(title: title)
          : FutureBuilder<Uint8List>(
              future: HgCoverRepository.instance.load(url),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final logicalWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : (width ?? MediaQuery.sizeOf(context).width);
                      final scale = MediaQuery.devicePixelRatioOf(
                        context,
                      ).clamp(1.0, 1.5);
                      final cacheWidth = (logicalWidth * scale).round().clamp(
                        160,
                        900,
                      );
                      return Image.memory(
                        snapshot.data!,
                        width: width,
                        height: height,
                        fit: fit,
                        cacheWidth: cacheWidth,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (context, error, stackTrace) =>
                            _CoverPlaceholder(title: title),
                      );
                    },
                  );
                }
                if (snapshot.hasError) {
                  return _CoverPlaceholder(title: title, error: true);
                }
                return _CoverPlaceholder(title: title, loading: true);
              },
            ),
    );
    if (borderRadius == BorderRadius.zero) return child;
    return ClipRRect(borderRadius: borderRadius, child: child);
  }
}

class HgAvatar extends StatelessWidget {
  const HgAvatar({
    super.key,
    required this.name,
    this.url = '',
    this.size = 42,
    this.color = const Color(0xFFFF6B3D),
  });

  final String name;
  final String url;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: HgCoverImage(
          url: url,
          width: size,
          height: size,
          title: name,
          borderRadius: BorderRadius.circular(size / 2),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.72), color],
        ),
      ),
      child: Text(
        name.isEmpty ? '果' : name.characters.first,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({
    this.title = '',
    this.loading = false,
    this.error = false,
  });

  final String title;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = dark
        ? const [Color(0xFF272727), Color(0xFF1C1C1E), Color(0xFF111111)]
        : const [Color(0xFFE9E9EB), Color(0xFFF2F2F3), Color(0xFFDCDCDE)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: error ? colors.reversed.toList() : colors,
        ),
      ),
      child: Center(
        child: loading
            ? Icon(
                Icons.movie_filter_outlined,
                color: (dark ? Colors.white : HgColors.ink).withValues(
                  alpha: 0.24,
                ),
                size: 28,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.movie_filter_rounded,
                    color: (dark ? Colors.white : HgColors.ink).withValues(
                      alpha: 0.42,
                    ),
                    size: 30,
                  ),
                  if (title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Text(
                        title,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: (dark ? Colors.white : HgColors.ink)
                              .withValues(alpha: 0.58),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
