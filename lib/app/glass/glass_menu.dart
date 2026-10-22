import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'glass_tokens.dart';

class GlassMenuItem<T> {
  const GlassMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final T value;
  final IconData icon;
  final String label;
  final bool destructive;
}

Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required Offset position,
  required List<GlassMenuItem<T>> items,
}) {
  final still = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: still ? Duration.zero : GlassTokens.menu,
    pageBuilder: (context, _, _) =>
        _MenuLayer<T>(position: position, items: items),
    transitionBuilder: (context, animation, _, child) {
      final curved = animation.drive(CurveTween(curve: GlassTokens.curve));
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          alignment: Alignment.topLeft,
          scale: curved.drive(Tween(begin: 0.94, end: 1.0)),
          child: child,
        ),
      );
    },
  );
}

class _MenuLayer<T> extends StatelessWidget {
  const _MenuLayer({required this.position, required this.items});

  final Offset position;
  final List<GlassMenuItem<T>> items;

  static const double _width = 248;
  static const double _rowHeight = 48;
  static const double _edge = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final height = items.length * _rowHeight + 12;
    final left = position.dx.clamp(_edge, size.width - _width - _edge);
    final top = position.dy.clamp(_edge, size.height - height - _edge);

    return Stack(
      children: [
        Positioned(
          left: left.toDouble(),
          top: top.toDouble(),
          width: _width,
          child: Material(
            type: MaterialType.transparency,
            child: GlassSurface(
              intensity: GlassIntensity.thick,
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in items)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).pop(item.value),
                      child: SizedBox(
                        height: _rowHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 20,
                                color: item.destructive
                                    ? scheme.error
                                    : scheme.onSurface,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: item.destructive
                                        ? scheme.error
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
