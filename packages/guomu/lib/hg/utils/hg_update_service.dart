import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../app_metadata.dart';

class HgReleaseAsset {
  const HgReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final String downloadUrl;
  final int size;

  factory HgReleaseAsset.fromJson(Map<String, dynamic> json) {
    return HgReleaseAsset(
      name: json['name']?.toString() ?? '',
      downloadUrl: json['browser_download_url']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class HgReleaseUpdate {
  const HgReleaseUpdate({
    required this.tagName,
    required this.title,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  final String tagName;
  final String title;
  final String body;
  final String htmlUrl;
  final String publishedAt;
  final List<HgReleaseAsset> assets;

  String get version => tagName.replaceFirst(RegExp(r'^[vV]'), '');

  HgReleaseAsset? get androidAsset => _assetWithExtension('.apk');
  HgReleaseAsset? get iosAsset => _assetWithExtension('.ipa');

  HgReleaseAsset? _assetWithExtension(String extension) {
    for (final asset in assets) {
      if (asset.name.toLowerCase().endsWith(extension)) return asset;
    }
    return null;
  }

  String downloadUrlFor(TargetPlatform platform) {
    if (!kIsWeb && platform == TargetPlatform.android) {
      return androidAsset?.downloadUrl ?? htmlUrl;
    }
    if (!kIsWeb && platform == TargetPlatform.iOS) {
      return iosAsset?.downloadUrl ?? htmlUrl;
    }
    return htmlUrl;
  }

  factory HgReleaseUpdate.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'];
    return HgReleaseUpdate(
      tagName: json['tag_name']?.toString() ?? '',
      title: json['name']?.toString() ?? json['tag_name']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      htmlUrl: json['html_url']?.toString() ?? '',
      publishedAt: json['published_at']?.toString() ?? '',
      assets: rawAssets is List
          ? rawAssets
                .whereType<Map>()
                .map(
                  (item) =>
                      HgReleaseAsset.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.downloadUrl.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class HgUpdateCheckResult {
  const HgUpdateCheckResult({
    required this.currentVersion,
    required this.release,
  });

  final String currentVersion;
  final HgReleaseUpdate release;

  bool get hasUpdate =>
      HgUpdateService.compareVersions(release.version, currentVersion) > 0;
}

abstract final class HgUpdateService {
  static const releasesApi =
      'https://api.github.com/repos/DearLicy/guomu/releases/latest';

  static Future<HgUpdateCheckResult> checkLatest() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ),
    );
    try {
      final response = await dio.get<dynamic>(releasesApi);
      final data = response.data;
      if (data is! Map) throw const HgUpdateException('更新接口返回异常');
      final release = HgReleaseUpdate.fromJson(Map<String, dynamic>.from(data));
      if (release.version.isEmpty || release.htmlUrl.isEmpty) {
        throw const HgUpdateException('没有找到可用的 Release');
      }
      return HgUpdateCheckResult(
        currentVersion: HgAppMetadata.version,
        release: release,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw const HgUpdateException('GitHub 上还没有发布版本');
      }
      if (error.response?.statusCode == 403) {
        throw const HgUpdateException('GitHub API 访问次数已达上限，请稍后重试');
      }
      throw const HgUpdateException('无法连接 GitHub 更新服务');
    }
  }

  static int compareVersions(String left, String right) {
    final a = _versionParts(left);
    final b = _versionParts(right);
    final length = a.length > b.length ? a.length : b.length;
    for (var index = 0; index < length; index++) {
      final av = index < a.length ? a[index] : 0;
      final bv = index < b.length ? b[index] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  static List<int> _versionParts(String value) {
    final clean = value
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first;
    return clean
        .split('.')
        .map(
          (part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? '') ?? 0,
        )
        .toList(growable: false);
  }

  static String plainReleaseBody(String body) {
    return body
        .split('\n')
        .map((line) {
          final trimmed = line.trimRight();
          if (trimmed.startsWith('### ')) return trimmed.substring(4);
          if (trimmed.startsWith('## ')) return trimmed.substring(3);
          if (trimmed.startsWith('# ')) return trimmed.substring(2);
          if (trimmed.startsWith('- ')) return '• ${trimmed.substring(2)}';
          return trimmed;
        })
        .join('\n')
        .trim();
  }
}

class HgUpdateException implements Exception {
  const HgUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
