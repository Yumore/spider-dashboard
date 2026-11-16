import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hg_download_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_download_manager.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_components.dart';
import '../widgets/secure_cover.dart';
import 'short_video_page.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<HgDownloadManager>();
    final tasks = manager.tasks;
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      appBar: AppBar(
        title: const Text('我的下载'),
        actions: [
          IconButton(
            tooltip: '检查追更',
            onPressed: () async {
              await context.read<HgDownloadManager>().checkForUpdates();
              if (context.mounted) showHgSnack(context, '已检查追更');
            },
            icon: const Icon(Icons.sync_rounded),
          ),
          if (tasks.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清除全部缓存？'),
                    content: const Text('会删除已下载的所有短剧文件，不影响账号和历史。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await manager.clear();
              },
              child: const Text('清空'),
            ),
        ],
      ),
      body: tasks.isEmpty
          ? const HgEmptyState(
              icon: Icons.download_for_offline_outlined,
              title: '还没有离线缓存',
              message: '在短剧详情页点击“缓存全集”，未完结剧集也会记录追更。',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _DownloadTile(
                  task: task,
                  manager: manager,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ShortVideoPage(
                        videoIds: [task.videoId],
                        initialEpisode: task.episodes.isEmpty
                            ? 1
                            : task.episodes.keys.reduce(
                                (a, b) => a > b ? a : b,
                              ),
                        title: task.title,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.task,
    required this.manager,
    required this.onOpen,
  });

  final HgDownloadTask task;
  final HgDownloadManager manager;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final downloaded = task.episodes.length;
    final total = task.totalEpisodes > 0 ? task.totalEpisodes : downloaded;
    final progress = task.isDownloading
        ? task.progress.clamp(0.0, 1.0)
        : total > 0
        ? (downloaded / total).clamp(0.0, 1.0)
        : 0.0;
    return Material(
      color: context.hgSurface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 70,
                  height: 96,
                  child: HgCoverImage(url: task.cover, title: task.title),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.hgOnSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.isDownloading
                          ? '${task.state} · ${formatSpeed(task.speedBytesPerSecond)}'
                          : '${task.state} · 已缓存 $downloaded/$total 集',
                      style: TextStyle(
                        color: task.isDownloading
                            ? HgColors.orange
                            : context.hgMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress <= 0 ? null : progress,
                        minHeight: 5,
                        backgroundColor: context.hgSurfaceMuted,
                        color: HgColors.orange,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Text(
                          formatBytes(task.downloadedBytes),
                          style: TextStyle(
                            color: context.hgMuted,
                            fontSize: 10.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          task.autoUpdate ? '自动缓存新集' : '仅保留当前缓存',
                          style: TextStyle(
                            color: context.hgMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Switch(
                          value: task.autoUpdate,
                          onChanged: (value) =>
                              manager.setAutoUpdate(task.videoId, value),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '删除缓存',
                          onPressed: () => manager.remove(task.videoId),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: context.hgMuted,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
