import 'package:flutter/painting.dart';

/// Paper colors are fixed and ignore the app theme, so a page stays white
/// with dark ink even in dark mode.
abstract final class PaperColors {
  static const Color surface = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFD9DEE3);
  static const Color ink = Color(0xFF1B1B1F);
}
