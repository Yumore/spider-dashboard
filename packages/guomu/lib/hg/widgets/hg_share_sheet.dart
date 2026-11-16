import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/hg_theme.dart';
import 'hg_adaptive_sheet.dart';
import '../utils/hg_share.dart';

Future<void> showHgShareSheet(
  BuildContext context, {
  required String title,
  required String url,
  String subtitle = '黄果短剧',
}) {
  return showHgAdaptiveSheetBuilder<void>(
    context,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (_) => _ShareSheet(title: title, url: url, subtitle: subtitle),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.title,
    required this.url,
    required this.subtitle,
  });

  final String title;
  final String url;
  final String subtitle;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _copying = false;
  bool _copied = false;
  bool _sharing = false;
  String? _hint;

  Future<void> _copy() async {
    if (_copying) return;
    setState(() {
      _copying = true;
      _hint = null;
    });
    await Clipboard.setData(
      ClipboardData(text: '${widget.title}\n${widget.url}'),
    );
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _copying = false;
      _copied = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _systemShare() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _hint = null;
    });
    final shared = await HgShare.shareText(
      title: widget.title,
      text: widget.subtitle,
      url: widget.url,
    );
    if (!mounted) return;
    if (shared) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _sharing = false;
      _hint = '系统分享不可用，可以复制链接';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 9, 18, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.hgLine,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '分享到',
              style: TextStyle(
                color: context.hgOnSurface,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: context.hgSurfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: HgColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF2B2B2E),
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Color(0xFF96969A),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (HgShare.canSystemShare) ...[
                  _ShareAction(
                    icon: Icons.ios_share_rounded,
                    label: _sharing ? '正在打开…' : '系统分享',
                    onTap: _systemShare,
                  ),
                  const SizedBox(width: 28),
                ],
                _ShareAction(
                  icon: _copied ? Icons.check_rounded : Icons.link_rounded,
                  label: _copied ? '已复制' : '复制链接',
                  active: _copied,
                  onTap: _copy,
                ),
              ],
            ),
            if (_hint != null) ...[
              const SizedBox(height: 12),
              Text(
                _hint!,
                style: const TextStyle(
                  color: Color(0xFF9B6A55),
                  fontSize: 11.5,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.maybePop(context),
                style: TextButton.styleFrom(
                  backgroundColor: context.hgSurfaceMuted,
                  foregroundColor: context.hgOnSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFEAF7F0) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? const Color(0xFFB9E5CC)
                      : const Color(0xFFE8E8EA),
                ),
              ),
              child: Icon(
                icon,
                color: active ? const Color(0xFF2A9D63) : HgColors.ink,
                size: 23,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF55555A),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
