import 'package:flutter/material.dart';

import '../theme/hg_theme.dart';

/// 原生 App 风格的统一下拉刷新入口。
///
/// iOS 使用 Cupertino 的圆形指示器，Android 使用低高度的 Material 指示器；
/// 页面只依赖这个组件，后续替换刷新动画不会影响业务页。
class HgRefreshIndicator extends StatelessWidget {
  const HgRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 8,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double edgeOffset;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      color: HgColors.orange,
      backgroundColor: context.hgSurface,
      displacement: 48,
      edgeOffset: edgeOffset,
      strokeWidth: 2.2,
      elevation: 0,
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      child: child,
    );
  }
}
