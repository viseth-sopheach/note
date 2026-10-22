import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'glass_tokens.dart';

class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.children,
    this.intensity = GlassIntensity.regular,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  });

  final List<Widget> children;
  final GlassIntensity intensity;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: GlassTokens.radiusPill,
      intensity: intensity,
      padding: padding,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
