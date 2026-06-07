import 'package:flutter/material.dart';

/// App-wide theming. A GXS-style purple seed drives the Material 3 palette.
class AppTheme {
  AppTheme._();

  /// GXS-inspired violet. Adjust this single value to retune the whole theme.
  static const Color seed = Color(0xFF6C2BD9);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}
