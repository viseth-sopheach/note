import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/measure_controller.dart';

/// Ruler or protractor drawn above the pages. Place it inside the zoomed
/// content, filling it. [scale] returns the current zoom.
class MeasureOverlay extends StatelessWidget {
  const MeasureOverlay({
    super.key,
    required this.controller,
    required this.scale,
  });

  final MeasureController controller;
  final double Function() scale;

  static const Color _fill = Color(0xB3FFF1B8);
  static const Color _ink = Color(0xFF3A3A3A);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        switch (controller.kind) {
          case MeasureKind.none:
            return const SizedBox.shrink();
          case MeasureKind.ruler:
            return Stack(children: [_ruler()]);
          case MeasureKind.protractor:
            return Stack(children: [_protractor()]);
        }
      },
    );
  }

  Widget _handle({required bool leading}) => _Handle(
        leading: leading,
        controller: controller,
        scale: scale,
      );

  Widget _ruler() {
    const w = MeasureController.rulerLength;
    const h = MeasureController.rulerThickness;
    const hs = MeasureController.handleSize;
    final c = controller;

    return Positioned(
      left: c.cx - w / 2,
      top: c.cy - h / 2,
      width: w,
      height: h,
      child: Transform.rotate(
        angle: c.angle,
        child: Stack(
          children: [
            Positioned.fill(
              child: _DragSurface(
                cursor: SystemMouseCursors.move,
                onStart: c.beginInteraction,
                onDelta: (d) {
                  final s = scale();
                  c.translate(d.dx / s, d.dy / s);
                },
                onEnd: c.endInteraction,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _RulerPainter(_fill, _ink)),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${c.degrees.round() % 180}°',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 6,
              top: (h - hs) / 2,
              width: hs,
              height: hs,
              child: _handle(leading: true),
            ),
            Positioned(
              right: 6,
              top: (h - hs) / 2,
              width: hs,
              height: hs,
              child: _handle(leading: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _protractor() {
    const r = MeasureController.protractorRadius;
    const hs = MeasureController.handleSize;
    const below = hs / 2;
    final c = controller;

    return Positioned(
      left: c.cx - r,
      top: c.cy - r,
      width: r * 2,
      height: r + below,
      child: Transform.rotate(
        angle: c.angle,
        alignment: Alignment(0, 2 * r / (r + below) - 1),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipPath(
                clipper: _HalfDiscClipper(),
                child: _DragSurface(
                  cursor: SystemMouseCursors.move,
                  onStart: c.beginInteraction,
                  onDelta: (d) {
                    final s = scale();
                    c.translate(d.dx / s, d.dy / s);
                  },
                  onEnd: c.endInteraction,
                  child: const RepaintBoundary(
                    child: CustomPaint(
                      painter: _ProtractorPainter(_fill, _ink),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6,
              top: r - hs / 2,
              width: hs,
              height: hs,
              child: _handle(leading: true),
            ),
            Positioned(
              right: 6,
              top: r - hs / 2,
              width: hs,
              height: hs,
              child: _handle(leading: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listens to one pointer and reports its movement in screen pixels.
class _DragSurface extends StatefulWidget {
  const _DragSurface({
    required this.onStart,
    required this.onDelta,
    required this.onEnd,
    required this.child,
    required this.cursor,
  });

  final VoidCallback onStart;
  final ValueChanged<Offset> onDelta;
  final VoidCallback onEnd;
  final Widget child;
  final MouseCursor cursor;

  @override
  State<_DragSurface> createState() => _DragSurfaceState();
}

class _DragSurfaceState extends State<_DragSurface> {
  int? _pointer;

  void _release(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_pointer != null) return;
          _pointer = e.pointer;
          widget.onStart();
        },
        onPointerMove: (e) {
          if (e.pointer == _pointer) widget.onDelta(e.delta);
        },
        onPointerUp: (e) => _release(e.pointer),
        onPointerCancel: (e) => _release(e.pointer),
        child: widget.child,
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.leading,
    required this.controller,
    required this.scale,
  });

  final bool leading;
  final MeasureController controller;
  final double Function() scale;

  @override
  Widget build(BuildContext context) {
    return _DragSurface(
      cursor: SystemMouseCursors.precise,
      onStart: controller.beginInteraction,
      onDelta: (d) {
        final s = scale();
        controller.rotateByHandle(d.dx / s, d.dy / s, leading: leading);
      },
      onEnd: controller.endInteraction,
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF1E5AA8),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.rotate_right, size: 18, color: Colors.white),
      ),
    );
  }
}

class _HalfDiscClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final r = size.width / 2;
    return Path()
      ..moveTo(0, r)
      ..arcTo(
        Rect.fromCircle(center: Offset(r, r), radius: r),
        math.pi,
        math.pi,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(_HalfDiscClipper oldClipper) => false;
}

void _label(Canvas canvas, String text, Offset center, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter(this.fill, this.ink);

  final Color fill;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(body, Paint()..color = fill);
    canvas.drawRRect(
      body,
      Paint()
        ..color = ink.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke,
    );

    final tick = Paint()
      ..color = ink
      ..strokeWidth = 1;
    const mm = MeasureController.cm / 10;
    final count = (size.width / mm).floor();
    final style = TextStyle(color: ink, fontSize: 10);

    for (var i = 0; i <= count; i++) {
      final x = i * mm;
      final isCm = i % 10 == 0;
      final isHalf = i % 5 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, isCm ? 16 : (isHalf ? 11 : 7)),
        tick,
      );
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - (isCm ? 10 : (isHalf ? 7 : 4))),
        tick,
      );
      if (isCm && i > 0 && x < size.width - 16) {
        _label(canvas, '${i ~/ 10}', Offset(x, 26), style);
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) => false;
}

class _ProtractorPainter extends CustomPainter {
  const _ProtractorPainter(this.fill, this.ink);

  final Color fill;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    const hs = MeasureController.handleSize;

    final disc = Path()
      ..moveTo(0, r)
      ..arcTo(Rect.fromCircle(center: center, radius: r), math.pi, math.pi, false)
      ..close();
    canvas.drawPath(disc, Paint()..color = fill);
    canvas.drawPath(
      disc,
      Paint()
        ..color = ink.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke,
    );

    final tick = Paint()
      ..color = ink
      ..strokeWidth = 1;
    final outer = TextStyle(color: ink, fontSize: 10);
    final inner = TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 9);

    for (var deg = 0; deg <= 180; deg++) {
      final a = deg * math.pi / 180;
      final dir = Offset(math.cos(a), -math.sin(a));
      final len = deg % 10 == 0 ? 18.0 : (deg % 5 == 0 ? 12.0 : 7.0);
      canvas.drawLine(center + dir * r, center + dir * (r - len), tick);
      if (deg % 10 == 0 && deg > 0 && deg < 180) {
        _label(canvas, '$deg', center + dir * (r - 32), outer);
        _label(canvas, '${180 - deg}', center + dir * (r - 52), inner);
      }
    }

    // Base line, centre mark.
    canvas.drawLine(Offset(hs, r), Offset(size.width - hs, r), tick);
    canvas.drawLine(center, center + const Offset(0, -26), tick);
    canvas.drawCircle(center, 3, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_ProtractorPainter oldDelegate) => false;
}