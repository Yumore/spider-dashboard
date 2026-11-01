import 'package:flutter/material.dart';

import 'content_page_theme.dart';

/// Pushes a content page.
///
/// Every module used to repeat `Navigator.of(context).push(MaterialPageRoute(
/// builder: (_) => ...))`; routing content pages through one helper keeps the
/// navigation contract in one place.
Future<T?> openContentPage<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        builder: (context) =>
            ContentPageTheme(child: Builder(builder: builder)),
      ),
    );
