import 'package:flutter/material.dart';

/// 统一的底部面板：默认半屏，可拖到约 90% 高度，向下拖到底部关闭。
///
/// 手势、拖动条和模态路由全部复用 Flutter 自带实现，面板本身只负责
/// 中档/大档吸附以及给内部 ScrollView 提供同一个 ScrollController。
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
    enableDrag: dragEnabled,
    showDragHandle: dragEnabled,
    backgroundColor: theme.colorScheme.surface,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.42),
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => HgAdaptiveSheet(
      childScrollable: childScrollable,
      isDismissible: isDismissible,
      initialSize: initialSize,
      minSize: minSize,
      maxSize: maxSize,
      child: child,
    ),
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

class HgAdaptiveSheet extends StatelessWidget {
  const HgAdaptiveSheet({
    super.key,
    required this.child,
    required this.isDismissible,
    this.initialSize = 0.56,
    this.minSize = 0.32,
    this.maxSize = 0.9,
    this.childScrollable = false,
  });

  final Widget child;
  final bool isDismissible;
  final double initialSize;
  final double minSize;
  final double maxSize;
  final bool childScrollable;

  @override
  Widget build(BuildContext context) {
    final initial = initialSize.clamp(0.28, 0.92).toDouble();
    final minimum = minSize.clamp(0.2, initial).toDouble();
    final maximum = maxSize.clamp(initial, 0.96).toDouble();
    final snapSizes = maximum > initial + 0.02
        ? <double>[initial, maximum]
        : <double>[maximum];
    final physics = Theme.of(context).platform == TargetPlatform.iOS
        ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
        : const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

    return PopScope(
      canPop: isDismissible,
      child: DraggableScrollableSheet(
        key: const ValueKey('hg-adaptive-sheet'),
        expand: false,
        initialChildSize: initial,
        minChildSize: minimum,
        maxChildSize: maximum,
        snap: true,
        snapSizes: snapSizes,
        shouldCloseOnMinExtent: isDismissible,
        builder: (context, scrollController) {
          final content = childScrollable
              ? PrimaryScrollController(
                  controller: scrollController,
                  child: child,
                )
              : SingleChildScrollView(
                  controller: scrollController,
                  physics: physics,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.zero,
                  child: child,
                );
          return SafeArea(top: false, child: content);
        },
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
    initialSize: 0.44,
    minSize: 0.28,
    maxSize: 0.74,
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
    return Padding(
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
    );
  }
}
