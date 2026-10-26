import 'package:flutter/material.dart';

/// Single source for the app's colours; native splash colours mirror these.
abstract final class AppPalette {
  static const background = Color(0xFF0F0D13);
  static const surfaceLow = Color(0xFF191620);
  static const surface = Color(0xFF1F1B27);
  static const surfaceHigh = Color(0xFF282333);
  static const outline = Color(0xFF3A3345);

  static const text = Color(0xFFEDE7F3);
  static const textMuted = Color(0xFFBFB3CC);

  static const orchid = Color(0xFFD6A1FF);
  static const orchidContainer = Color(0xFF4F2A72);
  static const rose = Color(0xFFF6C9E6);
  static const roseContainer = Color(0xFF3A2040);
  static const amber = Color(0xFFF5C77E);
  static const amberContainer = Color(0xFF4A3818);
}

abstract final class AppTheme {
  static Color _on(Color c) =>
      c.computeLuminance() > 0.45 ? const Color(0xFF1A1020) : Colors.white;

  static Color _mix(Color c, double t) =>
      Color.lerp(AppPalette.background, c, t)!;

  static ThemeData dark({Color? accent, Color? secondary}) {
    final primary = accent ?? AppPalette.orchid;
    final second = secondary ?? AppPalette.rose;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppPalette.background,
      surfaceContainerLowest: AppPalette.background,
      surfaceContainerLow: AppPalette.surfaceLow,
      surfaceContainer: AppPalette.surface,
      surfaceContainerHigh: AppPalette.surface,
      surfaceContainerHighest: AppPalette.surfaceHigh,
      outline: AppPalette.textMuted,
      outlineVariant: AppPalette.outline,
      onSurface: AppPalette.text,
      onSurfaceVariant: AppPalette.textMuted,
      primary: primary,
      onPrimary: accent == null ? const Color(0xFF38105A) : _on(primary),
      primaryContainer:
          accent == null ? AppPalette.orchidContainer : _mix(primary, 0.4),
      onPrimaryContainer: accent == null
          ? const Color(0xFFF0DCFF)
          : Color.lerp(primary, Colors.white, 0.8),
      secondary: second,
      onSecondary: secondary == null ? const Color(0xFF4A1633) : _on(second),
      secondaryContainer:
          secondary == null ? AppPalette.roseContainer : _mix(second, 0.25),
      onSecondaryContainer: second,
      tertiary: AppPalette.amber,
      onTertiary: const Color(0xFF3F2C00),
      tertiaryContainer: AppPalette.amberContainer,
      onTertiaryContainer: const Color(0xFFFFE2AE),
    );

    final base = ThemeData.dark().textTheme.apply(
          bodyColor: AppPalette.text,
          displayColor: scheme.onSecondaryContainer,
        );
    final titles = scheme.onSecondaryContainer;
    final textTheme = base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(color: titles),
      headlineMedium: base.headlineMedium?.copyWith(color: titles),
      headlineSmall: base.headlineSmall?.copyWith(color: titles),
      titleLarge: base.titleLarge?.copyWith(color: titles),
      titleMedium: base.titleMedium?.copyWith(color: titles),
      titleSmall: base.titleSmall?.copyWith(color: titles),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        titleTextStyle: textTheme.titleLarge,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.primary,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow.withAlpha(0xE6),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(
          scheme.surfaceContainerLow.withAlpha(0xF0),
        ),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withAlpha(0xE6),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
