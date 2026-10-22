import 'package:flutter/material.dart';

class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: dark ? 0.16 : 0.10),
            Colors.transparent,
            scheme.tertiary.withValues(alpha: dark ? 0.12 : 0.07),
          ],
        ),
      ),
      child: child,
    );
  }
}
