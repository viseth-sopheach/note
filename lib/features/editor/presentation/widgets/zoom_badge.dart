import 'package:flutter/foundation.dart';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../../../app/glass/glass_surface.dart';
import '../../../../app/glass/glass_tokens.dart';

class ZoomBadge extends StatelessWidget {
  const ZoomBadge({super.key, required this.ratio, required this.visible});

  final ValueListenable<double> ratio;
  final ValueListenable<bool> visible;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: Listenable.merge([ratio, visible]),
        builder: (context, _) => AnimatedOpacity(
          opacity: visible.value ? 1 : 0,
          duration: still ? Duration.zero : GlassTokens.press,
          child: Center(
            child: GlassSurface(
              radius: GlassTokens.radiusPill,
              intensity: GlassIntensity.thick,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                '${(ratio.value * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
