import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'glass_tokens.dart';

enum GlassButtonKind { primary, plain, destructive }

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = GlassButtonKind.primary,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GlassButtonKind kind;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = const StadiumBorder();
    const size = Size(64, GlassTokens.minTarget);
    final text = Text(label);
    final iconWidget = icon == null ? null : Icon(icon, size: 18);

    if (kind == GlassButtonKind.plain) {
      final style = TextButton.styleFrom(shape: shape, minimumSize: size);
      return iconWidget == null
          ? TextButton(
              autofocus: autofocus,
              style: style,
              onPressed: onPressed,
              child: text,
            )
          : TextButton.icon(
              autofocus: autofocus,
              style: style,
              onPressed: onPressed,
              icon: iconWidget,
              label: text,
            );
    }

    final destructive = kind == GlassButtonKind.destructive;
    final style = FilledButton.styleFrom(
      shape: shape,
      minimumSize: size,
      backgroundColor: destructive ? scheme.error : null,
      foregroundColor: destructive ? scheme.onError : null,
    );
    return iconWidget == null
        ? FilledButton(
            autofocus: autofocus,
            style: style,
            onPressed: onPressed,
            child: text,
          )
        : FilledButton.icon(
            autofocus: autofocus,
            style: style,
            onPressed: onPressed,
            icon: iconWidget,
            label: text,
          );
  }
}

class GlassFab extends StatelessWidget {
  const GlassFab({
    super.key,
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GlassSurface(
        radius: GlassTokens.radiusPill,
        intensity: GlassIntensity.thick,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
