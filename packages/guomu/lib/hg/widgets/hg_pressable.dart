import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 带水波纹关闭、轻微按压叠色的 [InkWell] 替代，列表行与卡片可点区域优先使用。
class HgInkWell extends StatelessWidget {
  const HgInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.customBorder,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        customBorder: customBorder,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return onSurface.withValues(alpha: 0.06);
          }
          return null;
        }),
        child: child,
      ),
    );
  }
}

/// 列表行、图标等可点区域的统一按压反馈：仅透明度/叠色变化，不缩放、不弹簧动效。
class HgPressable extends StatefulWidget {
  const HgPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.haptic = false,
    this.behavior = HitTestBehavior.opaque,
    this.pressedOpacity = 0.72,
    this.borderRadius,
    this.semanticLabel,
    this.button = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool haptic;
  final HitTestBehavior behavior;
  final double pressedOpacity;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final bool button;

  @override
  State<HgPressable> createState() => _HgPressableState();
}

class _HgPressableState extends State<HgPressable> {
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (!_interactive || widget.onTap == null) return;
    if (widget.haptic) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }
    widget.onTap!();
  }

  void _handleLongPress() {
    if (!_interactive || widget.onLongPress == null) return;
    if (widget.haptic) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedOpacity(
      opacity: _pressed ? widget.pressedOpacity : 1,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      child: widget.child,
    );

    Widget body = GestureDetector(
      behavior: widget.behavior,
      onTapDown: _interactive ? (_) => _setPressed(true) : null,
      onTapUp: _interactive ? (_) => _setPressed(false) : null,
      onTapCancel: _interactive ? () => _setPressed(false) : null,
      onTap: _interactive ? _handleTap : null,
      onLongPress: _interactive ? _handleLongPress : null,
      child: child,
    );

    if (widget.borderRadius != null) {
      body = ClipRRect(borderRadius: widget.borderRadius!, child: body);
    }

    if (widget.semanticLabel != null || widget.button) {
      body = Semantics(
        button: widget.button,
        enabled: _interactive,
        label: widget.semanticLabel,
        child: body,
      );
    }

    return body;
  }
}