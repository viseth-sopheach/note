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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    final opaque = MediaQuery.highContrastOf(context);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: opaque ? glass.solid : (dark ? const Color(0x3D000000) : null),
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
      ),
      child: CustomPaint(
        foregroundPainter: opaque
            ? null
            : _RimPainter(radius: radius, dark: dark),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
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
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(borderRadius: shape, child: surface),
      ),
    );
  }
}

/// Specular rim: bright top-left edge, faint middle, soft bottom-right edge.
class _RimPainter extends CustomPainter {
  const _RimPainter({required this.radius, required this.dark});

  final double radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(radius),
    );
    final rim = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: dark ? 0.55 : 0.9),
        Colors.white.withValues(alpha: dark ? 0.06 : 0.15),
        Colors.white.withValues(alpha: dark ? 0.22 : 0.5),
      ],
      stops: const [0, 0.5, 1],
    ).createShader(Offset.zero & size);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = rim
        ..isAntiAlias = true,
    );
    canvas.drawRRect(
      rrect.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: dark ? 0.06 : 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || old.dark != dark;
}
