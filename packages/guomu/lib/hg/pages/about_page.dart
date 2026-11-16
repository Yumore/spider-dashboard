import 'package:flutter/material.dart';

import '../app_metadata.dart';
import '../theme/hg_theme.dart';

class AboutGuomuPage extends StatelessWidget {
  const AboutGuomuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(6, top + 4, 18, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Text(
                    '关于果幕',
                    style: TextStyle(
                      color: context.hgOnSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                color: HgColors.ink,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: HgColors.orange,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55FF5F3D),
                          blurRadius: 28,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    '果幕',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '黄果短剧第三方 Flutter 客户端',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      HgAppMetadata.versionLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
            sliver: SliverList.list(
              children: [
                const _FeatureStrip(),
                const SizedBox(height: 14),
                _AboutSection(
                  icon: Icons.auto_awesome_rounded,
                  title: '为观看而生',
                  children: [
                    '果幕不是网页套壳。首页、剧场、吃瓜、榜单、我的和播放器都围绕短剧内容重新组织，减少无效层级和重复操作。',
                    '播放页支持上下滑、自动连播、邻近集预取、清屏观看、可拖动进度条和长按二倍速。',
                  ],
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _AboutSection(
                  icon: Icons.history_rounded,
                  title: '续播与缓存',
                  children: [
                    '本机保存当前剧集、播放秒数和时长。从追剧、历史、详情、榜单或专题进入，都会接上上一次的位置。',
                    '内容元数据、封面和已预加载的视频分片会保存在本机，无网络或接口波动时优先使用已有内容。',
                  ],
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _AboutSection(
                  icon: Icons.shield_outlined,
                  title: '数据边界',
                  children: [
                    '果幕不提供、不存储、不分发音视频内容。短剧、封面、评论与账号数据均来自用户选择的第三方站点。',
                    '账号会话、观看历史、追剧进度、主题和数据源保存在本机；项目仓库不包含用户凭据或私有密钥。',
                  ],
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _AboutSection(
                  icon: Icons.code_rounded,
                  title: '开源项目',
                  children: [
                    '项目地址：github.com/DearLicy/guomu',
                    '在线预览：dearlicy.github.io/guomu',
                    '本项目基于 GNU General Public License v3.0 开源。',
                  ],
                  theme: theme,
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    '果幕开源项目 · Flutter 构建',
                    style: TextStyle(
                      color: Color(0xFF9B9B9F),
                      fontSize: 10,
                      letterSpacing: 0.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip();

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.play_circle_outline_rounded, '沉浸播放'),
      (Icons.history_toggle_off_rounded, '本机续播'),
      (Icons.dns_outlined, '多源发现'),
    ];
    return Row(
      children: features
          .map(
            (feature) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: feature == features.last ? 0 : 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: context.hgSurface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Icon(feature.$1, size: 21, color: context.hgOnSurface),
                      const SizedBox(height: 7),
                      Text(
                        feature.$2,
                        style: TextStyle(
                          color: context.hgMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.icon,
    required this.title,
    required this.children,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final List<String> children;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: context.hgOnSurface),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: context.hgOnSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                text,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                  fontSize: 12.3,
                  height: 1.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
