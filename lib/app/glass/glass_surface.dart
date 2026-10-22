import 'dart:ui';

import 'package:flutter/material.dart';

import 'glass_theme.dart';
import 'glass_tokens.dart';

enum GlassIntensity { thin, regular, thick }

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.intensity = GlassIntensity.regular,
    this.radius = GlassTokens.radiusMedium,
    this.padding,
    this.elevated = true,
  });

  final Widget child;
  final GlassIntensity intensity;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool elevated;

  double get _sigma => switch (intensity) {
    GlassIntensity.thin => GlassTokens.blurThin,
    GlassIntensity.regular => GlassTokens.blurRegular,
    GlassIntensity.thick => GlassTokens.blurThick,
  };

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final shape = BorderRadius.circular(radius);
    final opaque = MediaQuery.highContrastOf(context);

    final decoration = BoxDecoration(
      borderRadius: shape,
      border: Border.all(color: glass.border),
      color: opaque ? glass.solid : null,
      gradient: opaque
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(glass.highlight, glass.fill),
                glass.fill,
              ],
              stops: const [0, 0.55],
            ),
    );

    Widget surface = DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );

    if (!opaque) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
        child: surface,
      );
    }

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: glass.shadow,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(borderRadius: shape, child: surface),
      ),
    );
  }
}
