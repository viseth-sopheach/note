import 'package:flutter/painting.dart';

/// Light paper is always white. Dark paper is used only in dark mode and is
/// lighter than the dark canvas (0xFF1C1C1E) so the page stays visible.
abstract final class PaperColors {
  static const Color surface = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFD9DEE3);
  static const Color ink = Color(0xFF1B1B1F);

  static const Color darkSurface = Color(0xFF2A2A2D);
  static const Color darkLine = Color(0xFF3F3F44);

  static Color surfaceFor(bool dark) => dark ? darkSurface : surface;
  static Color lineFor(bool dark) => dark ? darkLine : line;

  /// Display color of a stroke. Stored data is never changed.
  /// On dark paper, neutral colors (black ink) flip to light and dark
  /// colored inks are lightened so they stay readable.
  static int inkFor(int colorValue, {required bool darkPaper}) {
    if (!darkPaper) return colorValue;
    final hsl = HSLColor.fromColor(Color(colorValue));
    if (hsl.saturation < 0.15) {
      return hsl.withLightness(1 - hsl.lightness).toColor().toARGB32();
    }
    if (hsl.lightness < 0.6) {
      return hsl.withLightness(0.62).toColor().toARGB32();
    }
    return colorValue;
  }
}