import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_controllers.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/secure_cover.dart';
import 'edit_profile_sheet.dart';
import 'login_sheet.dart';

Future<void> showAccountSheet(BuildContext context) async {
  final auth = context.read<AuthController>();
  if (!auth.isLoggedIn || auth.user == null) {
    await showLoginSheet(context);
    return;
  }
  await showHgAdaptiveSheet<void>(
    context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    child: const _AccountSheet(),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  Future<void> _edit(BuildContext context) async {
    final user = context.read<AuthController>().user;
    if (user == null) return;
    await showEditProfileSheet(context, user);
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showHgAdaptiveSheet<bool>(
      context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      child: Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          decoration: BoxDecoration(
            color: context.hgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                Text(
                  '退出登录？',
                  style: TextStyle(
                    color: context.hgOnSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '追剧和历史仍会保留在本机，重新登录后可继续同步账号数据。',
                  style: TextStyle(
                    color: context.hgMuted,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: const Color(0xFFC64F45),
                  ),
                  child: const Text('退出登录'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthController>().logout();
      if (context.mounted) Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  HgAvatar(
                    name: user.nickname,
                    url: user.avatar,
                    size: 52,
                    color: colorFromHex(user.avatarColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF202124),
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID：${user.id}',
                          style: const TextStyle(
                            color: Color(0xFF88888D),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _AccountAction(
              icon: Icons.edit_outlined,
              title: '编辑资料',
              subtitle: '昵称、个性签名和头像',
              onTap: () => _edit(context),
            ),
            _AccountAction(
              icon: Icons.logout_rounded,
              title: '退出登录',
              subtitle: '保留本机缓存和播放历史',
              color: const Color(0xFFC64F45),
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 13, 18, 13),
        child: Row(
          children: [
            Icon(icon, size: 21, color: effective),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: effective,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF98989C),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 19),
          ],
        ),
      ),
    );
  }
}
