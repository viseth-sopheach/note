import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color defaultSeed = Colors.blueGrey;

  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  static ThemeData build(
    Brightness brightness, {
    Color seed = defaultSeed,
    bool compact = false,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 44,
        titleSpacing: 8,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
    );
  }
}
