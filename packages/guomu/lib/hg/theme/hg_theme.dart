import 'package:flutter/material.dart';

abstract final class HgColors {
  static const orange = Color(0xFFFF5F3D);
  static const orangeSoft = Color(0xFFFF8B70);
  static const gold = Color(0xFFFFB84D);
  static const lavender = Color(0xFF8B8B8B);
  static const ink = Color(0xFF1C1C1E);
  static const mutedInk = Color(0xFF8A8A8E);
  static const night = Color(0xFF090909);
  static const nightSurface = Color(0xFF161616);
  static const paper = Color(0xFFF7F7F7);
  static const paperSurface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE9E9EB);
}

ThemeData buildHgTheme(Brightness brightness, {bool embedded = false}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: HgColors.orange,
    brightness: brightness,
    primary: HgColors.orange,
    secondary: dark ? const Color(0xFFE7E7E7) : HgColors.ink,
    surface: dark ? HgColors.nightSurface : HgColors.paperSurface,
  );
  final background = dark ? HgColors.night : HgColors.paper;
  final onSurface = dark ? const Color(0xFFF5F5F5) : HgColors.ink;
  final muted = dark ? const Color(0xFFA1A1A6) : HgColors.mutedInk;
  final outline = dark ? const Color(0xFF2C2C2E) : HgColors.line;
  final latinFont = embedded ? 'packages/guomu/GuomuLatin' : 'GuomuLatin';
  final cjkFont = embedded ? 'packages/guomu/GuomuCJK' : 'GuomuCJK';
  final textTheme = ThemeData(brightness: brightness).textTheme.apply(
    fontFamily: latinFont,
    bodyColor: onSurface,
    displayColor: onSurface,
    fontFamilyFallback: [cjkFont],
  );
  final roundedCard = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: latinFont,
    colorScheme: scheme.copyWith(
      surface: dark ? HgColors.nightSurface : HgColors.paperSurface,
      onSurface: onSurface,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.7),
      surfaceContainer: dark
          ? const Color(0xFF1D1D1F)
          : const Color(0xFFF5F5F6),
      surfaceContainerLow: dark
          ? const Color(0xFF181819)
          : const Color(0xFFFAFAFB),
      surfaceContainerHigh: dark
          ? const Color(0xFF28282A)
          : const Color(0xFFEFEFF1),
      surfaceContainerHighest: dark
          ? const Color(0xFF303033)
          : const Color(0xFFE8E8EB),
    ),
    scaffoldBackgroundColor: background,
    canvasColor: background,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    textTheme: textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.55),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? HgColors.nightSurface : HgColors.paperSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: roundedCard,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF202020) : const Color(0xFFF2F2F3),
      hintStyle: TextStyle(color: muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      prefixIconColor: muted,
      suffixIconColor: muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? Colors.white : HgColors.ink,
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            minimumSize: const Size(0, 50),
            side: BorderSide(color: outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style:
          TextButton.styleFrom(
            foregroundColor: dark ? Colors.white : HgColors.ink,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? const Color(0xFF202127) : const Color(0xFFF3F3F4),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        color: onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 62,
      elevation: 0,
      backgroundColor: dark ? const Color(0xF2161616) : Colors.white,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? HgColors.orange : muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 23,
          color: selected ? HgColors.orange : muted,
        );
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF181818) : Colors.white,
      modalBackgroundColor: dark ? const Color(0xFF181818) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFFF0EDE7) : HgColors.ink,
      contentTextStyle: TextStyle(color: dark ? HgColors.ink : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: HgColors.orange,
    ),
    dividerTheme: DividerThemeData(
      color: outline.withValues(alpha: 0.8),
      thickness: 0.5,
      space: 0.5,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(muted.withValues(alpha: 0.35)),
      radius: const Radius.circular(100),
      thickness: const WidgetStatePropertyAll(3),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // Flutter 的 predictive back 在 Android 上会叠加半透明旧页面，
        // 对沉浸式短剧客户端显得像网页转场，统一使用整页推入。
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

extension HgThemeContext on BuildContext {
  Color get hgSurface => Theme.of(this).colorScheme.surface;
  Color get hgSurfaceLow => Theme.of(this).colorScheme.surfaceContainerLow;
  Color get hgSurfaceMuted => Theme.of(this).colorScheme.surfaceContainer;
  Color get hgSurfaceHigh => Theme.of(this).colorScheme.surfaceContainerHigh;
  Color get hgOnSurface => Theme.of(this).colorScheme.onSurface;
  Color get hgMuted =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.48);
  Color get hgSubtle =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.34);
  Color get hgLine => Theme.of(this).colorScheme.outlineVariant;
}
