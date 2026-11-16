import 'package:flutter/material.dart';

import '../app_metadata.dart';
import '../theme/hg_theme.dart';

class UpdateHistoryPage extends StatelessWidget {
  const UpdateHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      appBar: AppBar(
        backgroundColor: context.hgSurfaceLow,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text(
          '更新记录',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
        itemCount: HgAppMetadata.releaseHistory.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final release = HgAppMetadata.releaseHistory[index];
          return _ReleaseCard(release: release, current: index == 0);
        },
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, required this.current});

  final HgReleaseRecord release;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: current ? context.hgOnSurface : context.hgSurfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  current ? '当前版本' : '历史版本',
                  style: TextStyle(
                    color: current ? context.hgSurface : context.hgMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                release.versionLabel,
                style: TextStyle(
                  color: context.hgMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (release.date.isNotEmpty)
                Text(
                  release.date,
                  style: TextStyle(color: context.hgSubtle, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            release.title,
            style: TextStyle(
              color: context.hgOnSurface,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          if (release.features.isNotEmpty)
            _ReleaseSection(title: '新增功能', items: release.features),
          if (release.improvements.isNotEmpty)
            _ReleaseSection(title: '体验优化', items: release.improvements),
          if (release.fixes.isNotEmpty)
            _ReleaseSection(title: '问题修复', items: release.fixes),
        ],
      ),
    );
  }
}

class _ReleaseSection extends StatelessWidget {
  const _ReleaseSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.hgOnSurface.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: Color(0xFF9B9B9F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF66666B),
                        fontSize: 12.5,
                        height: 1.62,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
