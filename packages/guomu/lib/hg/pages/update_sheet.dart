import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_metadata.dart';
import '../theme/hg_theme.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../utils/hg_update_service.dart';
import '../utils/hg_update_download.dart';

typedef HgUpdateDownloadAction =
    Future<String> Function(
      HgReleaseAsset asset, {
      CancelToken? cancelToken,
      void Function(int, int)? onProgress,
    });

Future<void> showHgUpdateResultSheet(
  BuildContext context,
  HgUpdateCheckResult result, {
  bool automatic = false,
  HgUpdateDownloadAction download = HgUpdateDownload.download,
}) {
  return showHgAdaptiveSheetBuilder<void>(
    context,
    childScrollable: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    initialSize: MediaQuery.sizeOf(context).height < 500 ? 0.9 : 0.62,
    builder: (_) => _HgUpdateSheet(
      result: result,
      automatic: automatic,
      download: download,
    ),
  );
}

class _HgUpdateSheet extends StatefulWidget {
  const _HgUpdateSheet({
    required this.result,
    required this.automatic,
    required this.download,
  });

  final HgUpdateCheckResult result;
  final bool automatic;
  final HgUpdateDownloadAction download;

  @override
  State<_HgUpdateSheet> createState() => _HgUpdateSheetState();
}

class _HgUpdateSheetState extends State<_HgUpdateSheet> {
  bool _opening = false;
  String? _error;
  CancelToken? _cancelToken;
  int _received = 0;
  int _total = 0;
  String? _downloadedPath;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _openRelease() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        widget.result.release.androidAsset != null) {
      final token = _cancelToken = CancelToken();
      try {
        final path =
            _downloadedPath ??
            await widget.download(
              widget.result.release.androidAsset!,
              cancelToken: token,
              onProgress: (received, total) {
                if (mounted) {
                  setState(() {
                    _received = received;
                    _total = total;
                  });
                }
              },
            );
        if (!mounted || token.isCancelled) return;
        setState(() => _downloadedPath = path);
        await HgUpdateDownload.install(path);
      } catch (error) {
        if (mounted &&
            !(error is DioException && CancelToken.isCancel(error))) {
          setState(
            () => _error = error is HgUpdateException
                ? error.message
                : error is PlatformException
                ? error.message ?? '无法开始安装，请重试'
                : '无法开始安装，请重试',
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _opening = false;
            _cancelToken = null;
          });
        }
      }
      return;
    }
    final platform = defaultTargetPlatform;
    final downloadUrl = platform == TargetPlatform.iOS
        ? widget.result.release.htmlUrl
        : widget.result.release.downloadUrlFor(platform);
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      setState(() {
        _opening = false;
        _error = '下载地址无效，请打开发布页查看';
      });
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted && !opened) setState(() => _error = '无法打开下载页面，请稍后重试');
    } catch (_) {
      if (mounted) setState(() => _error = '无法打开下载页面，请稍后重试');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String get _buttonLabel {
    if (kIsWeb) return '查看新版本';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        widget.result.release.androidAsset == null
            ? '打开发布页'
            : _downloadedPath == null
            ? '下载并安装'
            : '打开安装程序',
      TargetPlatform.iOS => '前往手动更新',
      _ => '打开发布页',
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = widget.result.hasUpdate;
    final release = widget.result.release;
    final body = HgUpdateService.plainReleaseBody(release.body);
    return Container(
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasUpdate ? HgColors.ink : context.hgSurfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      hasUpdate
                          ? Icons.system_update_alt_rounded
                          : Icons.check_rounded,
                      color: hasUpdate ? Colors.white : context.hgOnSurface,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasUpdate ? '发现新版本' : '已经是最新版本',
                          style: TextStyle(
                            color: context.hgOnSurface,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasUpdate
                              ? '${release.tagName} · 当前 ${HgAppMetadata.versionLabel}'
                              : '当前 ${HgAppMetadata.versionLabel}',
                          style: TextStyle(
                            color: context.hgMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            if (hasUpdate) ...[
              if (release.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      release.title,
                      style: TextStyle(
                        color: context.hgOnSurface.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: context.hgSurfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      body.isEmpty ? '本次更新暂无详细说明。' : body,
                      style: TextStyle(
                        color: context.hgOnSurface.withValues(alpha: 0.76),
                        fontSize: 12.5,
                        height: 1.7,
                      ),
                    ),
                  ),
                ),
              ),
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    'iOS 需要手动更新：前往发布页下载 IPA，再使用原来的签名或侧载工具覆盖安装。应用内无法直接安装更新。',
                    style: TextStyle(
                      color: context.hgMuted,
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ),
              if (_opening &&
                  !kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: _total > 0
                            ? (_received / _total).clamp(0, 1)
                            : null,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _total > 0
                                  ? '${(_received / _total * 100).clamp(0, 100).toStringAsFixed(0)}% · ${(_received / 1048576).toStringAsFixed(1)} / ${(_total / 1048576).toStringAsFixed(1)} MB'
                                  : '正在连接下载服务…',
                              style: TextStyle(
                                color: context.hgMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _cancelToken?.cancel(),
                            child: const Text('取消下载'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_downloadedPath != null && !_opening)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    '下载完成。如系统提示，请允许果幕安装应用，然后返回继续安装。',
                    style: TextStyle(
                      color: context.hgMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 11,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _opening ? null : _openRelease,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _opening
                          ? (!kIsWeb &&
                                    defaultTargetPlatform ==
                                        TargetPlatform.android
                                ? '正在下载…'
                                : '正在打开…')
                          : _buttonLabel,
                    ),
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Text(
                  '果幕会通过 GitHub Releases 检查后续版本，有新版本时会在设置页提示。',
                  style: TextStyle(
                    color: context.hgMuted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
