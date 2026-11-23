import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 统一的底部面板：默认半屏，可拖到约 90% 高度，向下拖到底部关闭。
///
/// 面板统一管理半屏、全屏与关闭状态；内容只在面板内部滚动，
/// 顶部横条直接控制面板高度，不再与外层弹窗抢拖动。
Future<T?> showHgAdaptiveSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isDismissible = true,
  bool? enableDrag,
  bool childScrollable = false,
  Color? barrierColor,
  double initialSize = 0.56,
  double minSize = 0.32,
  double maxSize = 0.9,
}) {
  final theme = Theme.of(context);
  final dragEnabled = enableDrag ?? isDismissible;
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: false,
    showDragHandle: false,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    backgroundColor: theme.colorScheme.surface,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.42),
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) {
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: HgAdaptiveSheet(
            childScrollable: childScrollable,
            isDismissible: isDismissible,
            enableDrag: dragEnabled,
            initialSize: initialSize,
            minSize: minSize,
            maxSize: maxSize,
            child: child,
          ),
        ),
      );
    },
  );
}

Future<T?> showHgAdaptiveSheetBuilder<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool? enableDrag,
  bool childScrollable = false,
  Color? barrierColor,
  double initialSize = 0.56,
  double minSize = 0.32,
  double maxSize = 0.9,
}) {
  return showHgAdaptiveSheet<T>(
    context,
    child: Builder(builder: builder),
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    childScrollable: childScrollable,
    barrierColor: barrierColor,
    initialSize: initialSize,
    minSize: minSize,
    maxSize: maxSize,
  );
}

class HgAdaptiveSheet extends StatefulWidget {
  const HgAdaptiveSheet({
    super.key,
    required this.child,
    required this.isDismissible,
    this.initialSize = 0.56,
    this.minSize = 0.32,
    this.maxSize = 0.9,
    this.childScrollable = false,
    this.enableDrag = true,
  });

  final Widget child;
  final bool isDismissible;
  final double initialSize;
  final double minSize;
  final double maxSize;
  final bool childScrollable;
  final bool enableDrag;

  @override
  State<HgAdaptiveSheet> createState() => _HgAdaptiveSheetState();
}

class _HgAdaptiveSheetState extends State<HgAdaptiveSheet> {
  late double _size;
  bool _dragging = false;

  double get _initial => widget.initialSize.clamp(0.28, 0.92).toDouble();
  double get _minimum => widget.minSize.clamp(0.2, _initial).toDouble();
  double get _maximum => widget.maxSize.clamp(_initial, 0.96).toDouble();

  @override
  void initState() {
    super.initState();
    _size = _initial;
  }

  @override
  void didUpdateWidget(covariant HgAdaptiveSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _size = _size.clamp(_minimum, _maximum);
  }

  void _startDrag(DragStartDetails details) {
    HapticFeedback.selectionClick();
    setState(() => _dragging = true);
  }

  void _update(DragUpdateDetails details) {
    final height = MediaQuery.sizeOf(context).height;
    setState(() {
      _dragging = true;
      _size = (_size - (details.primaryDelta ?? 0) / height).clamp(
        _minimum,
        _maximum,
      );
    });
  }

  void _settle([DragEndDetails? details]) {
    HapticFeedback.selectionClick();
    final velocity = details?.primaryVelocity ?? 0;
    final candidates = [_minimum, _initial, _maximum].where((stop) {
      if (velocity.abs() <= 350) return true;
      return velocity < 0 ? stop > _size + 0.01 : stop < _size - 0.01;
    }).toList();
    if (candidates.isEmpty) candidates.add(velocity < 0 ? _maximum : _minimum);
    final target = candidates.reduce(
      (a, b) => (_size - a).abs() < (_size - b).abs() ? a : b,
    );
    if (target == _minimum && widget.isDismissible) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _dragging = false;
      _size = target;
    });
  }

  void _toggle() {
    setState(() {
      _dragging = false;
      _size = _size > _initial + 0.05 ? _initial : _maximum;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * _maximum;
    final height = MediaQuery.sizeOf(context).height * _size;
    final physics = Theme.of(context).platform == TargetPlatform.iOS
        ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
        : const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    return PopScope(
      canPop: widget.isDismissible,
      child: AnimatedContainer(
        key: const ValueKey('hg-adaptive-sheet'),
        duration: _dragging || MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: height,
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          children: [
            if (widget.enableDrag)
              Semantics(
                button: true,
                label: '调整面板高度',
                hint: '轻点展开或收起，也可上下拖动',
                onTap: _toggle,
                child: GestureDetector(
                  key: const ValueKey('hg-sheet-drag-handle'),
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _startDrag,
                  onVerticalDragUpdate: _update,
                  onVerticalDragEnd: _settle,
                  onVerticalDragCancel: _settle,
                  onTap: _toggle,
                  child: SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: widget.childScrollable
                  ? widget.child
                  : SingleChildScrollView(
                      physics: physics,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: widget.child,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showHgConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
  bool destructive = false,
  IconData icon = Icons.help_outline_rounded,
}) async {
  final result = await showHgAdaptiveSheetBuilder<bool>(
    context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    initialSize: 0.64,
    minSize: 0.28,
    maxSize: 0.9,
    builder: (context) => _HgConfirmationSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _HgConfirmationSheet extends StatelessWidget {
  const _HgConfirmationSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    final accent = destructive ? danger : theme.colorScheme.onSurface;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: accent, size: 23),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const ValueKey('hg-confirm-sheet-action'),
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: destructive
                      ? danger
                      : theme.colorScheme.onSurface,
                  foregroundColor: destructive
                      ? theme.colorScheme.onError
                      : theme.colorScheme.surface,
                ),
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: 7),
            TextButton(
              key: const ValueKey('hg-confirm-sheet-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    );
  }
}
