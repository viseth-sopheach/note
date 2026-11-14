import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';

class LaserLayer extends StatefulWidget {
  const LaserLayer({
    super.key,
    required this.controller,
    this.origin = Offset.zero,
  });

  final DrawingController controller;
  final Offset origin;

  @override
  State<LaserLayer> createState() => _LaserLayerState();
}

class _LaserLayerState extends State<LaserLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    widget.controller.laserRepaint.addListener(_wake);
  }

  @override
  void didUpdateWidget(LaserLayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.laserRepaint.removeListener(_wake);
      widget.controller.laserRepaint.addListener(_wake);
    }
  }

  @override
  void dispose() {
    widget.controller.laserRepaint.removeListener(_wake);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _wake() {
    if (widget.controller.hasLaser && !_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    final alive = widget.controller.pruneLaser();
    _frame.value++;
    if (!alive && widget.controller.laserHead == null) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _LaserPainter(
            widget.controller,
            widget.origin,
            Listenable.merge([widget.controller.laserRepaint, _frame]),
          ),
        ),
      ),
    );
  }
}

class _LaserPainter extends CustomPainter {
  _LaserPainter(this.controller, this.origin, Listenable repaint)
    : super(repaint: repaint);

  final DrawingController controller;
  final Offset origin;

  static const Color _red = Color(0xFFFF2D2D);
  static const int _buckets = 8;
  static const MaskFilter _blur = MaskFilter.blur(BlurStyle.normal, 6);

  // Reused every frame, so painting allocates no Paint objects.
  final Paint _glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..maskFilter = _blur
    ..isAntiAlias = true;
  final Paint _core = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final Paint _fill = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final trail = controller.laserTrail;
    final head = controller.laserHead;
    if (trail.isEmpty && head == null) return;
    final now = controller.laserClockMs;
    final s = controller.laserScale;

    canvas.save();
    canvas.translate(origin.dx, origin.dy);

    // Segments are grouped by age into a few paths. Each path is stroked
    // once, so the blur runs a handful of times per frame instead of once
    // per segment, and overlapping segments do not beam brighter dots.
    final paths = List<Path?>.filled(_buckets, null);
    for (var i = 1; i < trail.length; i++) {
      final a = trail[i - 1], b = trail[i];
      if (b.t - a.t > 250) continue; // gap between two separate strokes
      final f = (1 - (now - b.t) / DrawingController.laserLifetimeMs).clamp(
        0.0,
        1.0,
      );
      if (f <= 0) continue;
      final bi = math.min(_buckets - 1, (f * _buckets).floor());
      (paths[bi] ??= Path())
        ..moveTo(a.x, a.y)
        ..lineTo(b.x, b.y);
    }

    for (var i = 0; i < _buckets; i++) {
      final path = paths[i];
      if (path == null) continue;
      final f = (i + 0.5) / _buckets;
      _glow
        ..color = _red.withValues(alpha: 0.35 * f)
        ..strokeWidth = (4 + 12 * f) * s;
      canvas.drawPath(path, _glow);
    }
    for (var i = 0; i < _buckets; i++) {
      final path = paths[i];
      if (path == null) continue;
      final f = (i + 0.5) / _buckets;
      _core
        ..color = _red.withValues(alpha: f)
        ..strokeWidth = (1.5 + 4 * f) * s;
      canvas.drawPath(path, _core);
    }

    if (head != null) {
      final c = Offset(head.x, head.y);
      _fill
        ..color = _red.withValues(alpha: 0.4)
        ..maskFilter = _blur;
      canvas.drawCircle(c, 11 * s, _fill);
      _fill
        ..color = _red
        ..maskFilter = null;
      canvas.drawCircle(c, 6 * s, _fill);
      _fill.color = const Color(0xFFFFFFFF);
      canvas.drawCircle(c, 2.5 * s, _fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LaserPainter old) =>
      old.controller != controller || old.origin != origin;
}
