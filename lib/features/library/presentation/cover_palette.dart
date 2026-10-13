import 'package:flutter/material.dart';

abstract final class CoverPalette {
  static const List<Color> colors = [
    Color(0xFF3F5F8A), // slate blue
    Color(0xFF4F7F6A), // sage green
    Color(0xFF8A4F4F), // brick
    Color(0xFF7A5C99), // muted purple
    Color(0xFFB07D3A), // amber
    Color(0xFF3A3A3A), // charcoal
  ];

  /// Readable icon/text color on top of [background].
  static Color onColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }
}