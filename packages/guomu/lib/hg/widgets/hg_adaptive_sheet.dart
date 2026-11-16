import 'package:flutter/material.dart';

/// 统一的底部面板：默认半屏，可拖到约 90% 高度，向下拖到底部关闭。
/// 这样所有弹窗拥有一致的手势、圆角和安全区行为，而不是各页各自拼一个 Container。
Future<T?> showHgAdaptiveSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isDismissible = true,
  bool enableDrag = false,
  bool childScrollable = false,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.42),
    builder: (context) => HgAdaptiveSheet(
      showHandle: false,
      childScrollable: childScrollable,
      child: child,
    ),
  );
}

Future<T?> showHgAdaptiveSheetBuilder<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = false,
  bool childScrollable = false,
  Color? barrierColor,
}) {
  return showHgAdaptiveSheet<T>(
    context,
    child: Builder(builder: builder),
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    childScrollable: childScrollable,
    barrierColor: barrierColor,
  );
}

class HgAdaptiveSheet extends StatelessWidget {
  const HgAdaptiveSheet({
    super.key,
    required this.child,
    this.initialSize = 0.56,
    this.minSize = 0.24,
    this.maxSize = 0.88,
    this.showHandle = true,
    this.childScrollable = false,
  });

  final Widget child;
  final double initialSize;
  final double minSize;
  final double maxSize;
  final bool showHandle;
  final bool childScrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize.clamp(0.2, 0.95),
      minChildSize: minSize.clamp(0.12, initialSize),
      maxChildSize: maxSize.clamp(initialSize, 0.98),
      snap: true,
      snapSizes: [
        initialSize.clamp(0.2, 0.95),
        maxSize.clamp(initialSize, 0.98),
      ],
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: PrimaryScrollController(
            controller: scrollController,
            child: Column(
              children: [
                if (showHandle) const HgSheetDragHandle(),
                Expanded(
                  child: childScrollable
                      ? PrimaryScrollController(
                          controller: scrollController,
                          child: child,
                        )
                      : SingleChildScrollView(
                          controller: scrollController,
                          physics: const ClampingScrollPhysics(),
                          child: child,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HgSheetDragHandle extends StatelessWidget {
  const HgSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9, bottom: 4),
      child: Center(
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}
