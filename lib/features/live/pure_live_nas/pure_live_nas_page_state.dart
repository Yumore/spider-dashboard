import 'dart:async';

import 'package:dashboard/features/live/pure_live_nas/pure_live_nas_client.dart';
import 'package:dashboard/features/live/pure_live_nas/pure_live_nas_endpoint_store.dart';
import 'package:dashboard/features/live/pure_live_nas/pure_live_nas_page.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Owns endpoint editing, connectivity state, and opening the NAS WebUI.
class PureLiveNasPageState extends State<PureLiveNasPage> {
  final _controller = TextEditingController();
  final _store = PureLiveNasEndpointStore();
  final _client = const PureLiveNasClient();
  bool _loading = true;
  bool _connecting = false;
  bool _connected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEndpoint());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadEndpoint() async {
    final endpoint = await _store.read();
    if (!mounted) return;
    _controller.text = endpoint;
    setState(() => _loading = false);
    if (endpoint.isNotEmpty) unawaited(_connect());
  }

  String? _normalizeEndpoint() {
    final uri = Uri.tryParse(_controller.text.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    ).toString().replaceFirst(RegExp(r'/+$'), '');
  }

  Future<void> _connect() async {
    final endpoint = _normalizeEndpoint();
    if (endpoint == null) {
      setState(() {
        _connected = false;
        _error = '请输入不带路径、令牌或账号信息的 http(s) 服务地址';
      });
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _store.write(endpoint);
      await _client.checkHealth(endpoint);
      if (!mounted) return;
      setState(() {
        _controller.text = endpoint;
        _connected = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _error = '$error';
      });
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _openWebUi() async {
    final endpoint = _normalizeEndpoint();
    if (endpoint == null) {
      setState(() => _error = '请先配置有效的 NAS 地址');
      return;
    }
    final opened = await launchUrl(
      Uri.parse(endpoint),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() => _error = '无法打开 NAS 管理台');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pure Live NAS')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dns_outlined, color: colors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '自托管直播服务',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (_loading || _connecting)
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              _connected
                                  ? Icons.check_circle_outline
                                  : Icons.cloud_off_outlined,
                              color: _connected ? colors.primary : colors.outline,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '连接 Pure Live NAS，使用五个平台聚合、账号托管、关注同步、直播流代理与弹幕 Web 管理台。',
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _controller,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'NAS 地址',
                          hintText: 'http://192.168.1.20:8090',
                          prefixIcon: Icon(Icons.link),
                        ),
                        onSubmitted: (_) => _connect(),
                      ),
                      if (_error case final error?) ...[
                        const SizedBox(height: 10),
                        Text(
                          error,
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _connecting ? null : _connect,
                            icon: const Icon(Icons.sync),
                            label: const Text('保存并检查'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _connected ? _openWebUi : null,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('打开管理台'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('部署源码已迁入本工程'),
                      SizedBox(height: 8),
                      SelectableText(
                        'packages/purelive_nas/nas/deploy/docker-compose.yml',
                      ),
                      SizedBox(height: 8),
                      Text(
                        '在该目录复制 .env.example 为 .env 后执行 docker compose up -d --build。首次运行前请先检查端口、令牌及 NAS 数据目录。',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
