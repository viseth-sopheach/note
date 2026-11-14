import 'dart:ui';

import 'package:flutter/material.dart';

/// Blurred orb background that follows the current theme.
class SettingsBackground extends StatelessWidget {
  const SettingsBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF0B0D17) : const Color(0xFFF2F3F8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _Orb(420, const Color(0xFF7C6CFF), dark ? 0.35 : 0.22),
          ),
          Positioned(
            bottom: -160,
            right: -100,
            child: _Orb(480, const Color(0xFF3FA9F5), dark ? 0.25 : 0.18),
          ),
          Positioned(
            top: 220,
            right: 220,
            child: _Orb(300, const Color(0xFFE05CC8), dark ? 0.14 : 0.10),
          ),
          child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb(this.size, this.color, this.alpha);

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: 90,
          sigmaY: 90,
          tileMode: TileMode.decal,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: alpha),
          ),
        ),
      ),
    ),
  );
}