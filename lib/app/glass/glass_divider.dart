import 'package:flutter/material.dart';

import 'glass_theme.dart';

class GlassDivider extends StatelessWidget {
  const GlassDivider({super.key, this.indent = 16});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: context.glass.border),
      ),
    );
  }
}
