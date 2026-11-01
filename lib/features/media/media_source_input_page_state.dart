import 'package:dashboard/app/platform/app_platform.dart';
import 'package:dashboard/features/media/media_playback_page.dart';
import 'package:dashboard/features/media/media_stream_source.dart';
import 'package:dashboard/features/media/media_source_input_page.dart';
import 'package:dashboard/features/shared/ui/content_spacing.dart';
import 'package:dashboard/features/shared/ui/module_page_scaffold.dart';
import 'package:flutter/material.dart';

class MediaSourceInputPageState extends State<MediaSourceInputPage> {
  final TextEditingController _urlController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _openPlayer() async {
    if (!AppPlatform.supportsVideoPlayback) {
      setState(() => _error = '当前平台暂不支持内嵌媒体播放');
      return;
    }
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https')) {
      setState(() => _error = '请输入有效的 HTTP 或 HTTPS 媒体地址');
      return;
    }

    setState(() => _error = null);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaPlaybackPage(
          title: uri.host,
          sources: [MediaStreamSource(label: uri.host, url: uri)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ModulePageScaffold(
      title: '媒体直连播放',
      body: ListView(
        padding: ModulePageScaffold.pagePadding,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(ContentSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('播放媒体地址', style: theme.textTheme.titleMedium),
                  const SizedBox(height: ContentSpacing.xs),
                  Text(
                    '支持你有权访问的 HTTP(S) 直连媒体。地址只用于当前播放，不会保存。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: ContentSpacing.md),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '媒体 URL',
                      hintText: 'https://example.com/video.m3u8',
                      prefixIcon: Icon(Icons.link),
                    ),
                    onSubmitted: (_) => _openPlayer(),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: ContentSpacing.xs),
                    Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: ContentSpacing.md),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.icon(
                      onPressed: _openPlayer,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('打开播放器'),
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
