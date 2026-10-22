import 'package:flutter/animation.dart';

abstract final class GlassTokens {
  static const double blurThin = 8;
  static const double blurRegular = 14;
  static const double blurThick = 22;

  static const double radiusSmall = 12;
  static const double radiusMedium = 20;
  static const double radiusLarge = 28;
  static const double radiusPill = 999;

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;

  static const double minTarget = 44;
  static const double iconSize = 22;

  static const Duration press = Duration(milliseconds: 120);
  static const Duration menu = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;
}
