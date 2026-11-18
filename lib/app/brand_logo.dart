import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 36});

  final double size;

  static const String light = 'assets/icon/viseth_quill_light.svg';
  static const String dark = 'assets/icon/viseth_quill_dark.svg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      isDark ? dark : light,
      width: size,
      height: size,
      semanticsLabel: 'Viseth',
    );
  }
}
