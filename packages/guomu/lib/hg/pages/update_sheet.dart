import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_metadata.dart';
import '../theme/hg_theme.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../utils/hg_update_service.dart';

Future<void> showHgUpdateResultSheet(
  BuildContext context,
  HgUpdateCheckResult result, {
  bool automatic = false,
}) {
  return showHgAdaptiveSheetBuilder<void>(
    context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => _HgUpdateSheet(result: result, automatic: automatic),
  );
}

class _HgUpdateSheet extends StatefulWidget {
  const _HgUpdateSheet({required this.result, required this.automatic});

  final HgUpdateCheckResult result;
  final bool automatic;

  @override
  State<_HgUpdateSheet> createState() => _HgUpdateSheetState();
}

class _HgUpdateSheetState extends State<_HgUpdateSheet> {
  bool _opening = false;
  String? _error;

  Future<void> _openRelease() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    final platform = defaultTargetPlatform;
    final downloadUrl = widget.result.release.downloadUrlFor(platform);
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      setState(() {
        _opening = false;
        _error = '下载地址无效，请打开发布页查看';
      });
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (!opened) _error = '无法打开下载页面，请稍后重试';
    });
  }

  String get _buttonLabel {
    if (kIsWeb) return '查看新版本';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        widget.result.release.androidAsset == null ? '打开发布页' : '下载更新 APK',
      TargetPlatform.iOS =>
        widget.result.release.iosAsset == null ? '打开发布页' : '下载未签名 IPA',
      _ => '打开发布页',
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = widget.result.hasUpdate;
    final release = widget.result.release;
    final body = HgUpdateService.plainReleaseBody(release.body);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 9),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.hgLine,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasUpdate ? HgColors.ink : const Color(0xFFF1EFEB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      hasUpdate
                          ? Icons.system_update_alt_rounded
                          : Icons.check_rounded,
                      color: hasUpdate ? Colors.white : HgColors.ink,
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    'iOS 安装包未签名，下载后需要使用 Sideloadly、AltStore 或自己的证书完成签名安装。',
                    style: TextStyle(
                      color: Color(0xFF8A8A8F),
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFC64F45),
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
                      backgroundColor: HgColors.ink,
                      disabledBackgroundColor: const Color(0xFF9B9B9F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(_opening ? '正在打开…' : _buttonLabel),
                  ),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Text(
                  '果幕会通过 GitHub Releases 检查后续版本，有新版本时会在设置页提示。',
                  style: TextStyle(
                    color: Color(0xFF85858A),
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
