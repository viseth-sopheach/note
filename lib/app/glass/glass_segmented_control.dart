import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_theme.dart';
import 'glass_tokens.dart';

class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<GlassSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = context.glass;
    final still = MediaQuery.disableAnimationsOf(context);
    final duration = still ? Duration.zero : GlassTokens.menu;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GlassTokens.radiusPill),
        color: scheme.onSurface.withValues(alpha: 0.08),
        border: Border.all(color: glass.border),
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: s.value == selected,
                label: s.label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (s.value == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(s.value);
                  },
                  child: AnimatedContainer(
                    duration: duration,
                    curve: GlassTokens.curve,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        GlassTokens.radiusPill,
                      ),
                      color: s.value == selected
                          ? scheme.primary.withValues(alpha: 0.18)
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s.icon != null) ...[
                          Icon(
                            s.icon,
                            size: 18,
                            color: s.value == selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: s.value == selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: s.value == selected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
