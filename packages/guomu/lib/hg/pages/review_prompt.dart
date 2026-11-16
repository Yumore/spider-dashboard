import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/hg_theme.dart';
import '../widgets/hg_adaptive_sheet.dart';

const _reviewShownKey = 'guomu.review.prompt.shown.v1';
const _launchCountKey = 'guomu.review.prompt.launches.v1';

Future<void> maybeShowHgReviewPrompt(
  BuildContext context,
  SharedPreferences prefs,
) async {
  if (prefs.getBool(_reviewShownKey) ?? false) return;
  final launches = (prefs.getInt(_launchCountKey) ?? 0) + 1;
  await prefs.setInt(_launchCountKey, launches);
  if (launches < 3) return;
  await Future<void>.delayed(const Duration(seconds: 18));
  if (!context.mounted || (prefs.getBool(_reviewShownKey) ?? false)) return;
  await prefs.setBool(_reviewShownKey, true);
  if (!context.mounted) return;
  await showHgAdaptiveSheetBuilder<void>(
    context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (sheetContext) => Builder(
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.hgLine,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: HgColors.orange.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: HgColors.orange,
                  size: 27,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '果幕用着还顺手吗？',
                style: TextStyle(
                  color: context.hgOnSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '如果它帮你更舒服地追剧，可以去 GitHub 点一个 Star；有问题或建议，也欢迎在 Issues 里告诉我们。',
                style: TextStyle(
                  color: context.hgMuted,
                  fontSize: 13,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () =>
                      _open(context, 'https://github.com/DearLicy/guomu'),
                  icon: const Icon(Icons.star_rounded, size: 19),
                  label: const Text('去 GitHub 点 Star'),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _open(
                        context,
                        'https://github.com/DearLicy/guomu/issues',
                      ),
                      child: const Text('提交问题'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('以后再说'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  if (context.mounted) Navigator.maybePop(context);
}
