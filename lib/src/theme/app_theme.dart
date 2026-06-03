import 'package:flutter/material.dart';

/// App-wide theming. A calm green seed fits the "Food at Peace" feel.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF2E7D5B);

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
