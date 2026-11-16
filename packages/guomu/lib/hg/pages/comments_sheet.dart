import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../auth/app_controllers.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_adaptive_sheet.dart';
import '../widgets/hg_components.dart';
import '../widgets/secure_cover.dart';
import 'login_sheet.dart';

Future<void> showCommentsSheet(
  BuildContext context, {
  required int videoId,
  required int episode,
  required String title,
  required int totalComments,
}) {
  return showHgAdaptiveSheetBuilder<void>(
    context,
    childScrollable: true,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => CommentsSheet(
      videoId: videoId,
      episode: episode,
      title: title,
      totalComments: totalComments,
    ),
  );
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.videoId,
    required this.episode,
    required this.title,
    required this.totalComments,
  });

  final int videoId;
  final int episode;
  final String title;
  final int totalComments;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final Set<int> _loadingReplies = {};
  List<HgComment> _items = const [];
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _total = widget.totalComments;
    _load(reset: true);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 320) _loadMore();
    return false;
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final result = await context.read<HgApi>().comments(
        widget.videoId,
        widget.episode,
        page: reset ? 1 : _page + 1,
        size: 30,
      );
      if (!mounted) return;
      setState(() {
        _items = reset
            ? result.items
            : [
                ..._items,
                ...result.items.where(
                  (next) => !_items.any((old) => old.id == next.id),
                ),
              ];
        _page = result.pagination.page;
        _pages = result.pagination.pages;
        if (result.pagination.total > 0) _total = result.pagination.total;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _pages) return;
    setState(() => _loadingMore = true);
    await _load(reset: false);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    setState(() => _sending = true);
    try {
      await context.read<HgApi>().sendComment(
        widget.videoId,
        widget.episode,
        text,
      );
      if (!mounted) return;
      _input.clear();
      _focus.unfocus();
      await _load(reset: true);
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(HgComment comment) async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted || !loggedIn) return;
    final nextLiked = !comment.isLiked;
    _replaceComment(
      comment.copyWith(
        isLiked: nextLiked,
        likeCount: math.max(0, comment.likeCount + (nextLiked ? 1 : -1)),
      ),
    );
    try {
      await context.read<HgApi>().likeComment(
        widget.videoId,
        comment.id,
        nextLiked,
      );
    } catch (error) {
      if (!mounted) return;
      _replaceComment(comment);
      showHgSnack(context, cleanError(error));
    }
  }

  void _replaceComment(HgComment comment) {
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((item) => item.id == comment.id ? comment : item)
          .toList(growable: false);
    });
  }

  Future<void> _toggleReplies(HgComment comment) async {
    if (comment.replies.isNotEmpty) {
      _replaceComment(comment.copyWith(replies: const []));
      return;
    }
    if (_loadingReplies.contains(comment.id)) return;
    setState(() => _loadingReplies.add(comment.id));
    try {
      final page = await context.read<HgApi>().commentReplies(
        widget.videoId,
        comment.id,
        size: 30,
      );
      if (!mounted) return;
      _replaceComment(comment.copyWith(replies: page.items));
    } catch (error) {
      if (mounted) showHgSnack(context, cleanError(error));
    } finally {
      if (mounted) setState(() => _loadingReplies.remove(comment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = size.height * 0.84 - math.min(inset * 0.72, 220);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: sheetHeight,
      decoration: BoxDecoration(
        color: context.hgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 9),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5E7),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${_total > 0 ? formatCount(_total) : ''}条评论',
                  style: TextStyle(
                    color: context.hgOnSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Positioned(
                  left: 10,
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.hgOnSurface,
                      size: 29,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(auth)),
          _CommentComposer(
            controller: _input,
            focusNode: _focus,
            sending: _sending,
            enabled: auth.isLoggedIn,
            onSend: _send,
            onLogin: () => showLoginSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AuthController auth) {
    if (_loading && _items.isEmpty) return const HgLoading();
    if (_error != null && _items.isEmpty) {
      return HgErrorState(error: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return const HgEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: '还没有评论',
        message: '看完这一集，来留下第一句话。',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final comment = _items[index];
          return _CommentRow(
            comment: comment,
            loadingReplies: _loadingReplies.contains(comment.id),
            onLike: () => _toggleLike(comment),
            onToggleReplies: comment.replyCount > 0
                ? () => _toggleReplies(comment)
                : null,
          );
        },
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.loadingReplies,
    required this.onLike,
    this.onToggleReplies,
  });

  final HgComment comment;
  final bool loadingReplies;
  final VoidCallback onLike;
  final VoidCallback? onToggleReplies;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (comment.time.isNotEmpty) comment.time,
      if (comment.ipRegion.isNotEmpty) comment.ipRegion,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HgAvatar(
          name: comment.nickname,
          url: comment.avatar,
          size: 38,
          color: colorFromHex(comment.avatarColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        comment.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8B8B90),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onLike,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 6),
                      child: Column(
                        children: [
                          Icon(
                            comment.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: comment.isLiked
                                ? HgColors.orange
                                : const Color(0xFF747478),
                            size: 22,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCount(comment.likeCount),
                            style: const TextStyle(
                              color: Color(0xFF8C8C90),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                comment.text,
                style: const TextStyle(
                  color: Color(0xFF202124),
                  fontSize: 15,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meta,
                      style: const TextStyle(
                        color: Color(0xFF9B9B9F),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (comment.replyCount > 0 && onToggleReplies != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggleReplies,
                      child: Row(
                        children: [
                          if (loadingReplies)
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                              ),
                            )
                          else
                            const Text(
                              '回复',
                              style: TextStyle(
                                color: Color(0xFF6E6E73),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(width: 3),
                          Text(
                            '${comment.replyCount}',
                            style: const TextStyle(
                              color: Color(0xFF9B9B9F),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (comment.replies.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 7),
                  decoration: BoxDecoration(
                    color: context.hgSurfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: comment.replies
                        .take(3)
                        .map(
                          (reply) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Color(0xFF303034),
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                                children: [
                                  if (reply.replyToNickname.isNotEmpty)
                                    TextSpan(
                                      text: '回复 @${reply.replyToNickname}：',
                                      style: const TextStyle(
                                        color: Color(0xFF6E6E73),
                                      ),
                                    ),
                                  TextSpan(text: reply.text),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.enabled,
    required this.onSend,
    required this.onLogin,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 7, 16, 11),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: enabled ? null : onLogin,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: context.hgSurfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: !enabled,
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '有趣评论千千万，不如你也来一条？',
                    hintStyle: TextStyle(
                      color: Color(0xFF9B9B9F),
                      fontSize: 13,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: enabled
                ? (Theme.of(context).brightness == Brightness.dark
                      ? context.hgOnSurface
                      : HgColors.ink)
                : context.hgSurfaceMuted,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: enabled ? onSend : onLogin,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 46,
                height: 44,
                child: sending
                    ? Padding(
                        padding: const EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.hgSurface,
                        ),
                      )
                    : Icon(
                        enabled
                            ? Icons.arrow_upward_rounded
                            : Icons.login_rounded,
                        color: enabled
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? context.hgSurface
                                  : Colors.white)
                            : context.hgMuted,
                        size: 22,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
