// lib/app/glass/glass_scroll_thumb.dart
import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'glass_theme.dart';
import 'glass_tokens.dart';

class GlassScrollThumb extends StatelessWidget {
  const GlassScrollThumb({
    super.key,
    required this.visible,
    required this.fraction,
    required this.position,
    this.inset = const EdgeInsets.fromLTRB(0, 72, 4, 88),
  });

  final bool visible;
  final double fraction;
  final double position;
  final EdgeInsets inset;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    final fade = still ? Duration.zero : GlassTokens.menu;
    final follow = still ? Duration.zero : const Duration(milliseconds: 90);

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final track = (constraints.maxHeight - inset.vertical).clamp(
            0.0,
            double.infinity,
          );
          final thumb = (track * fraction).clamp(36.0, track).toDouble();
          final top = inset.top + (track - thumb) * position.clamp(0.0, 1.0);

          return AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: fade,
            curve: GlassTokens.curve,
            child: Stack(
              children: [
                Positioned(
                  right: inset.right + 1,
                  top: inset.top,
                  height: track,
                  width: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        GlassTokens.radiusPill,
                      ),
                      color: scheme.onSurface.withValues(alpha: 0.06),
                      border: Border.all(color: glass.border),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: follow,
                  curve: Curves.easeOut,
                  right: inset.right,
                  top: top,
                  width: 8,
                  height: thumb,
                  child: const GlassSurface(
                    radius: GlassTokens.radiusPill,
                    intensity: GlassIntensity.thin,
                    elevated: false,
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
