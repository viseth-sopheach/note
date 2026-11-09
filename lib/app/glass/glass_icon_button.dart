import 'package:flutter/material.dart';

import 'glass_theme.dart';
import 'glass_tokens.dart';

class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.size = GlassTokens.minTarget,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = context.glass;
    final enabled = widget.onPressed != null;
    final still = MediaQuery.disableAnimationsOf(context);
    final duration = still ? Duration.zero : GlassTokens.press;

    final dark = scheme.brightness == Brightness.dark;
    const accent = Color(0xFF0A84FF);
    final color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : widget.selected
        ? accent
        : (dark ? Colors.white.withValues(alpha: 0.92) : scheme.onSurface);

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        label: widget.tooltip,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1,
            duration: duration,
            curve: GlassTokens.curve,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onPressed,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              hoverColor: glass.hover,
              focusColor: scheme.primary.withValues(alpha: 0.16),
              child: AnimatedContainer(
                duration: duration,
                curve: GlassTokens.curve,
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.selected
                      ? accent.withValues(alpha: 0.24)
                      : Colors.transparent,
                  border: widget.selected
                      ? Border.all(
                          color: Colors.white.withValues(
                            alpha: dark ? 0.22 : 0.5,
                          ),
                        )
                      : null,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: color, size: GlassTokens.iconSize),
                  child: widget.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
