import 'package:flutter/material.dart';

/// App-wide theming — the single source of look & feel, so screens stay
/// style-free and the whole app restyles from here.
///
/// Direction: a modern, high-contrast, GXS-inspired **electric violet** system
/// with iOS-26 "Liquid Glass" cues — soft depth, layered translucent surfaces,
/// generous rounding, and floating cards. Dark is the hero; light is first-class.
class AppTheme {
  AppTheme._();

  // --- Brand palette -------------------------------------------------------
  /// Bright accent for dark surfaces (high contrast, pops).
  static const Color violet = Color(0xFF9B87FF);

  /// Deep accent for light surfaces.
  static const Color violetDeep = Color(0xFF6D28D9);

  /// Secondary accent — pairs with violet for the signature gradient.
  static const Color magenta = Color(0xFFE85CC4);

  /// Signature gradient for hero CTAs / highlights (use behind content).
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF7C5CFF), magenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Iridescent pastel gradient for **Beans** (the in-app credit) — gold → mint
  /// → sky → lavender, a holographic "jelly bean" sweep. Used for the Bean
  /// glyph, the balance hero, and top-up CTAs.
  static const LinearGradient beanGradient = LinearGradient(
    colors: [
      Color(0xFFFFD86B), // warm gold
      Color(0xFF8FE3A8), // mint
      Color(0xFF74C0FF), // sky
      Color(0xFFB79CFF), // lavender
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Deep ink that stays readable on the pastel bean gradient.
  static const Color beanInk = Color(0xFF2A2540);

  /// Solid accent sampled from the bean gradient, for CTAs / credited amounts.
  static const Color beanAccent = Color(0xFF7C93FF);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  // --- Color schemes -------------------------------------------------------
  static ColorScheme get _darkScheme =>
      ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.dark)
          .copyWith(
            primary: violet,
            onPrimary: const Color(0xFF1A0B40),
            primaryContainer: const Color(0xFF3B2A78),
            onPrimaryContainer: const Color(0xFFEADDFF),
            secondary: const Color(0xFFCBA8FF),
            tertiary: magenta,
            onTertiary: const Color(0xFF3A0A2E),
            // Deep violet-charcoal — not flat gray — for the GXS night feel.
            surface: const Color(0xFF0F0B1A),
            onSurface: const Color(0xFFF4F1FB),
            onSurfaceVariant: const Color(0xFFB9B1CC),
            surfaceContainerLowest: const Color(0xFF0A0712),
            surfaceContainerLow: const Color(0xFF161226),
            surfaceContainer: const Color(0xFF1B1630),
            surfaceContainerHigh: const Color(0xFF221C39),
            surfaceContainerHighest: const Color(0xFF2B2444),
            outline: const Color(0xFF4A4364),
            outlineVariant: const Color(0xFF2C2640),
          );

  static ColorScheme get _lightScheme =>
      ColorScheme.fromSeed(seedColor: violetDeep, brightness: Brightness.light)
          .copyWith(
            primary: violetDeep,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFEADDFF),
            onPrimaryContainer: const Color(0xFF22005C),
            tertiary: const Color(0xFFC026A6),
            surface: const Color(0xFFFBF9FF),
            onSurface: const Color(0xFF16121F),
            onSurfaceVariant: const Color(0xFF5B5470),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFF6F2FF),
            surfaceContainer: const Color(0xFFF1ECFB),
            surfaceContainerHigh: const Color(0xFFFFFFFF),
            surfaceContainerHighest: const Color(0xFFEDE7F8),
            outline: const Color(0xFFCDC4E0),
            outlineVariant: const Color(0xFFE4DDF1),
          );

  static ThemeData _build(Brightness brightness) {
    final scheme = brightness == Brightness.dark ? _darkScheme : _lightScheme;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final text = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),

      // Floating, rounded, borderless cards — the core surface element.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          shape: const StadiumBorder(),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 54),
          elevation: 0,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          shape: const StadiumBorder(),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Glassy floating pill — paired with the blur in HomeShell.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: scheme.primary.withValues(alpha: 0.20),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: text.labelLarge,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        iconColor: scheme.onSurfaceVariant,
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 2,
        extendedTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    );
  }

  // --- Typography ----------------------------------------------------------
  // Uses the platform font (San Francisco on iOS) — the most "Apple-native"
  // feel with no bundled fonts — refined for a modern, bold hierarchy.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
  }
}
