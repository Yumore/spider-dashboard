import 'package:dashboard/app/app_theme.dart';
import 'package:dashboard/app/user_info.dart';
import 'package:dashboard/app/utils.dart';
import 'package:dashboard/features/content_hub/content_hub_page.dart';
import 'package:dashboard/features/novel_sound/novel_sound_entry_page.dart';
import 'package:dashboard/views/news/news_home.dart';
import 'package:dashboard/views/novel/novel_home.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PersonalPage extends StatelessWidget {
  const PersonalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = context.watch<AppUserInfo>();
    final appTheme = context.watch<AppTheme>();

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildAccountTile(context, account),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: '个人内容',
            children: [
              _buildMenuTile(
                context,
                icon: Icons.favorite_border,
                title: '我的订阅',
                onTap: () => Utils.openSubscribePage(context),
              ),
              _buildMenuTile(
                context,
                icon: Icons.history,
                title: '浏览记录',
                onTap: () => Utils.openHistoryPage(context),
              ),
              _buildMenuTile(
                context,
                icon: Icons.chat_bubble_outline,
                title: '我的评论',
                onTap: () => Utils.openMyCommentPage(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            title: '偏好设置',
            children: [
              _buildMenuTile(
                context,
                icon: Icons.brightness_6_outlined,
                title: '外观模式',
                value: appTheme.themeModeName,
                onTap: () => appTheme.showThemeModeDialog(context),
              ),
              _buildMenuTile(
                context,
                icon: Icons.palette_outlined,
                title: '颜色主题',
                value: appTheme.themeColorName,
                leadingColor: appTheme.themeColor,
                onTap: () => _showColorPicker(context, appTheme),
              ),
              _buildMenuTile(
                context,
                icon: Icons.settings_outlined,
                title: '设置',
                onTap: () => Navigator.pushNamed(context, '/Setting'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            title: '内容入口',
            children: [
              _buildMenuTile(
                context,
                icon: Icons.grid_view_rounded,
                title: '全部内容模块',
                onTap: () => _openPage(context, const ContentHubPage()),
              ),
              _buildMenuTile(
                context,
                icon: Icons.auto_stories_outlined,
                title: '小说频道',
                onTap: () => _openPage(context, const NovelHomePage()),
              ),
              _buildMenuTile(
                context,
                icon: Icons.headphones_outlined,
                title: '什锦铺 · 小说与听书',
                onTap: () => _openPage(context, const NovelSoundEntryPage()),
              ),
              _buildMenuTile(
                context,
                icon: Icons.newspaper_outlined,
                title: '资讯频道',
                onTap: () => _openPage(context, const NewsHomePage()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Spider X',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context, AppUserInfo account) {
    final theme = Theme.of(context);
    final user = account.loginInfo;
    final isLoggedIn = account.isLogin && user != null;
    final title = isLoggedIn ? (user.nickname ?? '已登录用户') : '点击登录';
    final subtitle = isLoggedIn
        ? account.userProfile?.description ?? '账号与个人资料'
        : '登录后同步订阅与阅读记录';

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => isLoggedIn
            ? _confirmLogout(context, account)
            : Navigator.pushNamed(context, '/Login'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                backgroundImage:
                    isLoggedIn && user.photo != null && user.photo!.isNotEmpty
                    ? Utils.createCachedImageProvider(user.photo!)
                    : null,
                child: !isLoggedIn || user.photo == null || user.photo!.isEmpty
                    ? Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.primary,
                        size: 30,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? value,
    Color? leadingColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: leadingColor ?? theme.colorScheme.primary),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppUserInfo account) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) account.logout();
  }

  void _showColorPicker(BuildContext context, AppTheme appTheme) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('颜色主题'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SingleChildScrollView(
          child: RadioGroup<String>(
            groupValue: appTheme.themeColorName,
            onChanged: (value) {
              if (value == null) return;
              appTheme.changeThemeColor(
                AppTheme.themeColors.keys.toList().indexOf(value),
              );
              Navigator.pop(dialogContext);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in AppTheme.themeColors.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    title: Text(entry.key),
                    secondary: CircleAvatar(
                      radius: 11,
                      backgroundColor: entry.value,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
