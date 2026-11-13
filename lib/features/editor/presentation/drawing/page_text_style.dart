import 'package:flutter/painting.dart';

import '../../domain/page_text.dart';

abstract final class PageTextStyle {
  static const String latinFamily = 'Caveat';
  static const String khmerFamily = 'Fasthand';

  static TextStyle handwriting(double fontSize, {Color? color}) => TextStyle(
    color: color,
    fontSize: fontSize,
    height: 1.25,
    fontFamily: latinFamily,
    fontFamilyFallback: const [khmerFamily],
  );

  static TextStyle of(PageText t, {Color? color, double? fontSize}) =>
      t.handwriting
      ? handwriting(fontSize ?? t.fontSize, color: color)
      : TextStyle(color: color, fontSize: fontSize ?? t.fontSize, height: 1.25);
}
