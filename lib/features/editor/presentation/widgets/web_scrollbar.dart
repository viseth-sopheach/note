import 'dart:math' as math;

import 'package:flutter/material.dart';

class WebScrollbar extends StatefulWidget {
  const WebScrollbar({
    super.key,
    required this.axis,
    required this.viewport,
    required this.content,
    required this.position,
    required this.onScrollTo,
    required this.onPage,
    required this.onDragStart,
    this.alwaysVisible = false,
    this.revealed = false,
  });

  final Axis axis;

  /// Visible extent and total scrollable extent, in screen pixels.
  final double viewport;
  final double content;

  /// Current scroll offset, 0 to content - viewport.
  final double position;
  final ValueChanged<double> onScrollTo;

  /// Track click: -1 pages backwards, +1 forwards.
  final ValueChanged<int> onPage;
  final VoidCallback onDragStart;
  final bool alwaysVisible;

  /// Shown temporarily (for example while scrolling on a phone).
  final bool revealed;

  @override
  State<WebScrollbar> createState() => _WebScrollbarState();
}

class _WebScrollbarState extends State<WebScrollbar> {
  static const double _minThumb = 36;

  bool _hover = false;
  bool _dragging = false;
  double _dragPosition = 0;

  @override
  Widget build(BuildContext context) {
    final range = widget.content - widget.viewport;
    if (range <= 0.5) return const SizedBox.shrink();

    final vertical = widget.axis == Axis.vertical;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final active = _hover || _dragging;
    final visible = widget.alwaysVisible || widget.revealed || active;
    final thickness = active ? 12.0 : (widget.alwaysVisible ? 8.0 : 5.0);

    final thumbColor = dark
        ? (_dragging
              ? const Color(0xFFAEAEB2)
              : _hover
              ? const Color(0xFF8E8E93)
              : const Color(0xFF6E6E73))
        : (_dragging
              ? const Color(0xFF787878)
              : _hover
              ? const Color(0xFFA8A8A8)
              : const Color(0xFFC1C1C1));
    final trackColor = dark ? const Color(0x22FFFFFF) : const Color(0xFFF1F1F1);

    return IgnorePointer(
      ignoring: !visible,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: LayoutBuilder(
          builder: (context, box) {
            final track = vertical ? box.maxHeight : box.maxWidth;
            final thumbLength = math.min(
              track,
              math.max(_minThumb, track * widget.viewport / widget.content),
            );
            final free = track - thumbLength;
            final fraction = (widget.position / range).clamp(0.0, 1.0);
            final offset = free * fraction;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final p = vertical ? d.localPosition.dy : d.localPosition.dx;
                if (p < offset) {
                  widget.onPage(-1);
                } else if (p > offset + thumbLength) {
                  widget.onPage(1);
                }
              },
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: fade,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: active ? 1 : 0,
                        duration: fade,
                        child: ColoredBox(color: trackColor),
                      ),
                    ),
                    Positioned(
                      left: vertical ? 0 : offset,
                      right: vertical ? 0 : null,
                      top: vertical ? offset : 0,
                      bottom: vertical ? null : 0,
                      width: vertical ? null : thumbLength,
                      height: vertical ? thumbLength : null,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) {
                          _dragPosition = widget.position;
                          widget.onDragStart();
                          setState(() => _dragging = true);
                        },
                        onPointerMove: (e) {
                          if (!_dragging || free <= 0) return;
                          final d = vertical ? e.delta.dy : e.delta.dx;
                          _dragPosition = (_dragPosition + d / free * range)
                              .clamp(0.0, range);
                          widget.onScrollTo(_dragPosition);
                        },
                        onPointerUp: (_) => setState(() => _dragging = false),
                        onPointerCancel: (_) =>
                            setState(() => _dragging = false),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Align(
                            alignment: vertical
                                ? Alignment.centerRight
                                : Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: fade,
                              width: vertical ? thickness : double.infinity,
                              height: vertical ? double.infinity : thickness,
                              decoration: BoxDecoration(
                                color: thumbColor,
                                borderRadius: BorderRadius.circular(
                                  thickness / 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}