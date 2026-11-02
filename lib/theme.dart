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

  /// Near-black surface for definition and safety cards: dark enough that the
  /// patterned wallpaper can't show through the body text.
  static const card = Color(0xFF0A0810);

  /// Reserved for safety notes, so the warning colour means one thing.
  static const safety = Color(0xFFFFEE00);

  static const orchid = Color(0xFFD6A1FF);
  static const orchidContainer = Color(0xFF4F2A72);
  static const rose = Color(0xFFF6C9E6);
  static const roseContainer = Color(0xFF3A2040);
  static const amber = Color(0xFFF5C77E);
  static const amberContainer = Color(0xFF4A3818);
}

/// Screens are transparent, drawn over the app's single wallpaper, so a
/// cross-fade shows the outgoing and the incoming screen mixed together — two
/// sets of cards and headings ghosting through each other. Screens swap
/// instantly instead, which is also what the tab switches already do.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

abstract final class AppTheme {
  /// One radius for every text box in the app, matching the rounded swatch in
  /// the accent-colour picker.
  static const fieldRadius = 12.0;

  static const _transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _InstantPageTransitionsBuilder(),
      TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
      TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
      TargetPlatform.windows: _InstantPageTransitionsBuilder(),
      TargetPlatform.linux: _InstantPageTransitionsBuilder(),
      TargetPlatform.fuchsia: _InstantPageTransitionsBuilder(),
    },
  );

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
    // The selected destination's icon and its outline share this colour, so
    // the pill never looks like a different accent from the icon inside it.
    final navIcon = scheme.onSecondaryContainer;
    final fieldShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
    );
    OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );
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
      // Every text box shares one shape, fill and border, so fields built in
      // different screens look like the same control.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow.withAlpha(0xE6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: fieldBorder(scheme.outlineVariant),
        enabledBorder: fieldBorder(scheme.outlineVariant),
        disabledBorder: fieldBorder(scheme.outlineVariant),
        focusedBorder: fieldBorder(scheme.primary, 1.6),
        errorBorder: fieldBorder(scheme.error),
        focusedErrorBorder: fieldBorder(scheme.error, 1.6),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(
          scheme.surfaceContainerLow.withAlpha(0xF0),
        ),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        shape: WidgetStatePropertyAll(fieldShape),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      pageTransitionsTheme: _transitions,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withAlpha(0xE6),
        surfaceTintColor: Colors.transparent,
        // An outlined pill reads calmer than a filled one and keeps the label
        // legible when the accent colour is pale.
        indicatorColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: navIcon, width: 1.4),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? navIcon
                : scheme.onSurfaceVariant,
          ),
        ),
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
