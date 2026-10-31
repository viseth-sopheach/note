import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Browser-like scrolling for every [Scrollable]: persistent, hover-widening
/// scrollbars on desktop, default platform behaviour on phones.
class WebScrollBehavior extends MaterialScrollBehavior {
  const WebScrollBehavior();

  static bool get _desktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (!_desktop) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Color thumb(Set<WidgetState> s) => dark
        ? (s.contains(WidgetState.dragged)
              ? const Color(0xFFAEAEB2)
              : s.contains(WidgetState.hovered)
              ? const Color(0xFF8E8E93)
              : const Color(0xFF6E6E73))
        : (s.contains(WidgetState.dragged)
              ? const Color(0xFF787878)
              : s.contains(WidgetState.hovered)
              ? const Color(0xFFA8A8A8)
              : const Color(0xFFC1C1C1));

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thickness: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.hovered) ? 12 : 8,
        ),
        radius: const Radius.circular(6),
        thumbColor: WidgetStateProperty.resolveWith(thumb),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.hovered)
              ? (dark ? const Color(0x22FFFFFF) : const Color(0xFFF1F1F1))
              : Colors.transparent,
        ),
        minThumbLength: 36,
        interactive: true,
      ),
      child: Scrollbar(
        controller: details.controller,
        thumbVisibility: details.controller != null,
        child: child,
      ),
    );
  }
}