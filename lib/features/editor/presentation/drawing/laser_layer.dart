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
    widget.controller.live.addListener(_wake);
  }

  @override
  void didUpdateWidget(LaserLayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.live.removeListener(_wake);
      widget.controller.live.addListener(_wake);
    }
  }

  @override
  void dispose() {
    widget.controller.live.removeListener(_wake);
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
            Listenable.merge([widget.controller.live, _frame]),
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

  @override
  void paint(Canvas canvas, Size size) {
    final trail = controller.laserTrail;
    final head = controller.laserHead;
    if (trail.isEmpty && head == null) return;
    final now = controller.laserClockMs;

    canvas.save();
    canvas.translate(origin.dx, origin.dy);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..isAntiAlias = true;
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (var i = 1; i < trail.length; i++) {
      final a = trail[i - 1], b = trail[i];
      if (b.t - a.t > 250) continue; // gap between two separate strokes
      final f = (1 - (now - b.t) / DrawingController.laserLifetimeMs)
          .clamp(0.0, 1.0);
      if (f <= 0) continue;
      glow
        ..color = _red.withValues(alpha: 0.35 * f)
        ..strokeWidth = 4 + 12 * f;
      core
        ..color = _red.withValues(alpha: f)
        ..strokeWidth = 1.5 + 4 * f;
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), glow);
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), core);
    }

    if (head != null) {
      final c = Offset(head.x, head.y);
      canvas.drawCircle(
        c,
        11,
        Paint()
          ..color = _red.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(c, 6, Paint()..color = _red);
      canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFFFFFFFF));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LaserPainter old) =>
      old.controller != controller || old.origin != origin;
}