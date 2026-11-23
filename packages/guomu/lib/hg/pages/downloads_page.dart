import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hg_download_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_download_manager.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/hg_components.dart';
import '../widgets/secure_cover.dart';
import 'short_video_page.dart';
import '../widgets/hg_pressable.dart';

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
                final ok = await showHgConfirmSheet(
                  context,
                  title: '清除全部缓存？',
                  message: '会删除已下载的所有短剧文件，不影响账号和历史。',
                  confirmLabel: '清除全部',
                  destructive: true,
                  icon: Icons.delete_outline_rounded,
                );
                if (ok) await manager.clear();
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
    final currentReceived = (task.receivedBytes - task.downloadedBytes).clamp(
      0,
      task.receivedBytes,
    );
    final currentTotal = (task.totalBytes - task.downloadedBytes).clamp(
      0,
      task.totalBytes,
    );
    final statusText = switch (task.state) {
      '排队中' => '排队中 · 等待前序任务',
      '等待恢复' => '等待恢复下载',
      '已暂停' => task.lastError.isEmpty ? '已暂停' : '已暂停 · 可继续下载',
      _ when task.isDownloading =>
        '${task.state} · ${formatSpeed(task.speedBytesPerSecond)}',
      _ => '${task.state} · 已缓存 $downloaded/$total 集',
    };
    final bytesText = task.isDownloading
        ? currentTotal > 0
              ? '本集 ${formatBytes(currentReceived)} / ${formatBytes(currentTotal)}'
              : '已下载 ${formatBytes(task.receivedBytes)}'
        : formatBytes(task.downloadedBytes);
    final etaText =
        task.isDownloading &&
            task.speedBytesPerSecond > 0 &&
            task.totalBytes > task.receivedBytes
        ? '剩余 ${_formatEta((task.totalBytes - task.receivedBytes) ~/ task.speedBytesPerSecond)}'
        : null;
    return Material(
      color: context.hgSurface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: HgInkWell(
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
                      statusText,
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
                        value: progress,
                        minHeight: 5,
                        backgroundColor: context.hgSurfaceMuted,
                        color: HgColors.orange,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bytesText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.hgMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            etaText ?? (task.autoUpdate ? '自动缓存新集' : '仅保留当前缓存'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: context.hgMuted,
                              fontSize: 10.5,
                            ),
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
                        if (task.state == '已暂停' || task.state == '部分缓存')
                          IconButton(
                            key: ValueKey('hg-download-resume-${task.videoId}'),
                            tooltip: '继续下载',
                            onPressed: () async {
                              try {
                                await manager.resumeDownload(task.videoId);
                              } catch (error) {
                                if (context.mounted) {
                                  showHgSnack(context, cleanError(error));
                                }
                              }
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                          ),
                        IconButton(
                          tooltip: '删除缓存',
                          onPressed: () async {
                            final remove = await showHgConfirmSheet(
                              context,
                              title: '删除这部短剧的缓存？',
                              message: '会删除“${task.title}”的离线文件，观看记录仍会保留。',
                              confirmLabel: '删除缓存',
                              destructive: true,
                              icon: Icons.delete_outline_rounded,
                            );
                            if (remove) await manager.remove(task.videoId);
                          },
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

String _formatEta(int seconds) {
  if (seconds <= 0) return '即将完成';
  if (seconds < 60) return '$seconds 秒';
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes 分钟';
  final hours = (minutes / 60).floor();
  final rest = minutes % 60;
  return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分';
}
