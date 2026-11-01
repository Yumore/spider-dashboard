import 'dart:async';

import 'package:dashboard/features/media/media_playback_page.dart';
import 'package:dashboard/features/media/media_stream_source.dart';
import 'package:dashboard/features/movie/tvbox/tvbox_catalog_page.dart';
import 'package:dashboard/features/movie/tvbox/tvbox_cms_client.dart';
import 'package:dashboard/features/movie/tvbox/tvbox_source_site.dart';
import 'package:dashboard/features/movie/tvbox/tvbox_source_store.dart';
import 'package:dashboard/features/movie/tvbox/tvbox_vod_episode.dart';
import 'package:dashboard/features/movie/tvbox/tvbox_vod_item.dart';
import 'package:flutter/material.dart';

/// Owns source selection, CMS search requests and episode playback handoff.
class TvBoxCatalogPageState extends State<TvBoxCatalogPage> {
  final TvBoxCmsClient _client = TvBoxCmsClient();
  final TvBoxSourceStore _store = TvBoxSourceStore();
  final TextEditingController _catalogUrl = TextEditingController();
  final TextEditingController _keyword = TextEditingController();
  List<TvBoxSourceSite> _sites = const [];
  TvBoxSourceSite? _selected;
  List<TvBoxVodItem> _items = const [];
  bool _loading = false;
  String? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSource());
  }

  Future<void> _restoreSource() async {
    try {
      final saved = await _store.load();
      if (!mounted || saved == null || saved.isEmpty) return;
      _catalogUrl.text = saved;
      await _connect();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _connect() async {
    if (_loading) return;
    final requestGeneration = ++_requestGeneration;
    final uri = Uri.tryParse(_catalogUrl.text.trim());
    if (uri == null ||
        !<String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      setState(() => _error = '请输入有效的 HTTP/HTTPS TVBox 配置地址');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
    });
    try {
      final sites = await _client.loadCatalog(uri);
      await _store.save(uri.toString());
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _sites = sites;
        _selected = sites.first;
        _loading = false;
      });
      if (_keyword.text.trim().isNotEmpty) await _search();
    } catch (error) {
      if (mounted && requestGeneration == _requestGeneration) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _search() async {
    if (_loading) return;
    final site = _selected;
    final keyword = _keyword.text.trim();
    if (site == null || keyword.isEmpty) {
      setState(() => _error = '请先选择站点并输入搜索关键词');
      return;
    }
    final requestGeneration = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _client.search(site, keyword);
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (mounted && requestGeneration == _requestGeneration) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _openEpisodes(TvBoxVodItem item) async {
    if (_loading) return;
    final requestGeneration = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final site = _selected;
      if (site == null) {
        setState(() => _loading = false);
        return;
      }
      final detail = await _client.detail(site, item.id);
      final episodes = detail.episodes;
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() => _loading = false);
      if (episodes.isEmpty) {
        setState(() => _error = '该影片没有可播放的 HTTP(S) 选集');
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    item.title,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: episodes.length,
                    itemBuilder: (context, index) {
                      final episode = episodes[index];
                      return ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text(episode.name),
                        subtitle: Text(episode.group),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(_play(item.title, episodes, index));
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted && requestGeneration == _requestGeneration) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _play(
    String title,
    List<TvBoxVodEpisode> episodes,
    int index,
  ) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaPlaybackPage(
          title: '$title · ${episodes[index].name}',
          sources: [
            MediaStreamSource(
              label: episodes[index].group,
              url: episodes[index].url,
            ),
          ],
          previousPage: index == 0
              ? null
              : (_) => _playerPage(title, episodes, index - 1),
          nextPage: index >= episodes.length - 1
              ? null
              : (_) => _playerPage(title, episodes, index + 1),
          historyId: 'tvbox:${episodes[index].url}',
        ),
      ),
    );
  }

  Widget _playerPage(String title, List<TvBoxVodEpisode> episodes, int index) =>
      MediaPlaybackPage(
        title: '$title · ${episodes[index].name}',
        sources: [
          MediaStreamSource(
            label: episodes[index].group,
            url: episodes[index].url,
          ),
        ],
        previousPage: index == 0
            ? null
            : (_) => _playerPage(title, episodes, index - 1),
        nextPage: index >= episodes.length - 1
            ? null
            : (_) => _playerPage(title, episodes, index + 1),
        historyId: 'tvbox:${episodes[index].url}',
      );

  @override
  void dispose() {
    _client.dispose();
    _catalogUrl.dispose();
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TVBox / CMS 影视源')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _catalogUrl,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'TVBox / LibreTV JSON 配置地址',
            hintText: 'https://example.com/config.json',
            suffixIcon: IconButton(
              onPressed: _loading ? null : _connect,
              icon: const Icon(Icons.download),
            ),
          ),
          onSubmitted: (_) => _connect(),
        ),
        const SizedBox(height: 12),
        if (_sites.isNotEmpty)
          DropdownButtonFormField<TvBoxSourceSite>(
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'CMS 站点'),
            items: [
              for (final site in _sites)
                DropdownMenuItem(value: site, child: Text(site.name)),
            ],
            onChanged: _loading
                ? null
                : (site) => setState(() => _selected = site),
          ),
        if (_sites.isNotEmpty) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _keyword,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: '搜索影片',
              suffixIcon: IconButton(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!_loading && _items.isEmpty && _sites.isNotEmpty && _error == null)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('输入关键词搜索，结果只来自当前选择的源。'),
          ),
        for (final item in _items)
          Card(
            child: ListTile(
              leading: item.poster == null
                  ? const Icon(Icons.movie_outlined, size: 40)
                  : Image.network(
                      item.poster.toString(),
                      width: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.movie_outlined, size: 40),
                    ),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  item.year,
                  item.remark,
                ].where((part) => part.isNotEmpty).join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _loading ? null : () => _openEpisodes(item),
            ),
          ),
      ],
    ),
  );
}
