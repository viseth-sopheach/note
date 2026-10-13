import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color _seed = Colors.blueGrey;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }
}