import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/hg_components.dart';
import '../widgets/hg_refresh_indicator.dart';
import '../widgets/secure_cover.dart';
import 'creator_page.dart';
import '../widgets/hg_pressable.dart';

class MyFollowsPage extends StatefulWidget {
  const MyFollowsPage({super.key});

  @override
  State<MyFollowsPage> createState() => _MyFollowsPageState();
}

class _MyFollowsPageState extends State<MyFollowsPage> {
  List<HgAuthor> _items = const [];
  final Set<int> _updating = {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<HgApi>().myFollows(size: 50);
      if (mounted) setState(() => _items = page.items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unfollow(HgAuthor author) async {
    if (_updating.contains(author.id)) return;
    setState(() => _updating.add(author.id));
    try {
      await context.read<HgApi>().follow(author.id, false);
      if (!mounted) return;
      setState(
        () => _items = _items
            .where((item) => item.id != author.id)
            .toList(growable: false),
      );
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _updating.remove(author.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      appBar: _ActivityAppBar(title: '我的关注'),
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const HgLoading()
            : _error != null
            ? HgErrorState(error: _error!, onRetry: _load)
            : _items.isEmpty
            ? const HgEmptyState(
                icon: Icons.people_outline_rounded,
                title: '还没有关注用户',
                message: '在创作者主页关注后会显示在这里。',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final author = _items[index];
                  final updating = _updating.contains(author.id);
                  return Material(
                    color: context.hgSurface,
                    borderRadius: BorderRadius.circular(13),
                    clipBehavior: Clip.antiAlias,
                    child: HgInkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CreatorPage(userId: author.id),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          children: [
                            HgAvatar(
                              name: author.name,
                              url: author.avatar,
                              size: 46,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    author.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.hgOnSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${formatCount(author.followers)} 粉丝',
                                    style: TextStyle(
                                      color: context.hgMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: updating
                                  ? null
                                  : () => _unfollow(author),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                foregroundColor: const Color(0xFF5E5E63),
                                side: const BorderSide(
                                  color: Color(0xFFE4E4E6),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: Text(updating ? '处理中' : '取消关注'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class MyMessagesPage extends StatefulWidget {
  const MyMessagesPage({super.key});

  @override
  State<MyMessagesPage> createState() => _MyMessagesPageState();
}

class _MyMessagesPageState extends State<MyMessagesPage> {
  List<HgUserMessage> _items = const [];
  bool _loading = true;
  bool _markingAll = false;
  Object? _error;

  int get _unread => _items.where((item) => !item.isRead).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<HgApi>().myMessages(size: 50);
      if (mounted) setState(() => _items = page.items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(HgUserMessage message) async {
    if (message.isRead) return;
    try {
      await context.read<HgApi>().markMessageRead(message.id);
      if (!mounted) return;
      setState(
        () => _items = _items
            .map(
              (item) =>
                  item.id == message.id ? item.copyWith(isRead: true) : item,
            )
            .toList(growable: false),
      );
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    }
  }

  Future<void> _readAll() async {
    if (_markingAll || _unread == 0) return;
    setState(() => _markingAll = true);
    try {
      await context.read<HgApi>().markAllMessagesRead();
      if (!mounted) return;
      setState(
        () => _items = _items
            .map((item) => item.copyWith(isRead: true))
            .toList(growable: false),
      );
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _delete(HgUserMessage message) async {
    try {
      await context.read<HgApi>().deleteMessage(message.id);
      if (!mounted) return;
      setState(
        () => _items = _items
            .where((item) => item.id != message.id)
            .toList(growable: false),
      );
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    }
  }

  Future<void> _openMessage(HgUserMessage message) async {
    await _markRead(message);
    if (!mounted) return;
    await showHgAdaptiveSheetBuilder<void>(
      context,
      childScrollable: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.hgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.title,
                    style: TextStyle(
                      color: context.hgOnSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (message.time.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      message.time,
                      style: TextStyle(color: context.hgMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Text(
                  _plainMessage(message.content),
                  style: TextStyle(
                    color: context.hgOnSurface.withValues(alpha: 0.78),
                    fontSize: 14.5,
                    height: 1.75,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      appBar: _ActivityAppBar(
        title: '系统消息',
        action: _unread > 0
            ? TextButton(
                onPressed: _markingAll ? null : _readAll,
                child: Text(_markingAll ? '处理中…' : '全部已读'),
              )
            : null,
      ),
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const HgLoading()
            : _error != null
            ? HgErrorState(error: _error!, onRetry: _load)
            : _items.isEmpty
            ? const HgEmptyState(
                icon: Icons.mail_outline_rounded,
                title: '没有系统消息',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final message = _items[index];
                  return Material(
                    color: context.hgSurface,
                    borderRadius: BorderRadius.circular(13),
                    clipBehavior: Clip.antiAlias,
                    child: HgInkWell(
                      onTap: () => _openMessage(message),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 13, 6, 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 7, right: 9),
                              decoration: BoxDecoration(
                                color: message.isRead
                                    ? Colors.transparent
                                    : HgColors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFF262629),
                                      fontSize: 14,
                                      fontWeight: message.isRead
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _plainMessage(message.content),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF77777C),
                                      fontSize: 12,
                                      height: 1.55,
                                    ),
                                  ),
                                  if (message.time.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      message.time,
                                      style: const TextStyle(
                                        color: Color(0xFFA0A0A4),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                size: 19,
                              ),
                              onSelected: (value) {
                                if (value == 'read') _markRead(message);
                                if (value == 'delete') _delete(message);
                              },
                              itemBuilder: (_) => [
                                if (!message.isRead)
                                  const PopupMenuItem(
                                    value: 'read',
                                    child: Text('标为已读'),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除消息'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ActivityAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ActivityAppBar({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.hgSurfaceLow,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      actions: [if (action != null) action!, const SizedBox(width: 8)],
    );
  }
}

String _plainMessage(String source) {
  if (source.isEmpty) return '';
  if (!source.contains('<') || !source.contains('>')) return source.trim();
  final text = html_parser.parseFragment(source).text ?? '';
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class MyFollowersPage extends StatefulWidget {
  const MyFollowersPage({super.key});

  @override
  State<MyFollowersPage> createState() => _MyFollowersPageState();
}

class _MyFollowersPageState extends State<MyFollowersPage> {
  List<HgAuthor> _items = const [];
  final Set<int> _updating = {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<HgApi>().myFollowers(size: 50);
      if (mounted) setState(() => _items = page.items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(HgAuthor author) async {
    if (_updating.contains(author.id)) return;
    setState(() => _updating.add(author.id));
    try {
      await context.read<HgApi>().follow(author.id, !author.isFollowing);
      if (!mounted) return;
      setState(
        () => _items = _items
            .map(
              (item) => item.id == author.id
                  ? HgAuthor(
                      id: item.id,
                      name: item.name,
                      avatar: item.avatar,
                      followers: item.followers,
                      isFollowing: !item.isFollowing,
                    )
                  : item,
            )
            .toList(growable: false),
      );
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _updating.remove(author.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hgSurfaceLow,
      appBar: _ActivityAppBar(title: '我的粉丝'),
      body: HgRefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const HgLoading()
            : _error != null
            ? HgErrorState(error: _error!, onRetry: _load)
            : _items.isEmpty
            ? const HgEmptyState(
                icon: Icons.people_outline_rounded,
                title: '还没有粉丝',
                message: '官方账号暂无可展示的粉丝列表。',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final author = _items[index];
                  final updating = _updating.contains(author.id);
                  return Material(
                    color: context.hgSurface,
                    borderRadius: BorderRadius.circular(13),
                    clipBehavior: Clip.antiAlias,
                    child: HgInkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CreatorPage(userId: author.id),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          children: [
                            HgAvatar(
                              name: author.name,
                              url: author.avatar,
                              size: 46,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    author.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.hgOnSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${formatCount(author.followers)} 粉丝',
                                    style: TextStyle(
                                      color: context.hgMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: updating
                                  ? null
                                  : () => _toggle(author),
                              child: Text(
                                updating
                                    ? '处理中'
                                    : author.isFollowing
                                    ? '已关注'
                                    : '关注',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
