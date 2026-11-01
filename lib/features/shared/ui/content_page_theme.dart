import 'package:dashboard/features/shared/ui/content_radius.dart';
import 'package:flutter/material.dart';

/// Shared visual treatment inherited by routed content pages and module pages.
class ContentPageTheme extends StatelessWidget {
  const ContentPageTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        cardTheme: theme.cardTheme.copyWith(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ContentRadius.card),
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ContentRadius.icon),
          ),
        ),
      ),
      child: child,
    );
  }
}
