import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';
import '../paper/paper_colors.dart';
import 'ink_renderer.dart';

/// Lasso, selection line or box, handles and the strokes being transformed.
class SelectionLayer extends StatefulWidget {
  const SelectionLayer({
    super.key,
    required this.controller,
    this.origin = Offset.zero,
    this.darkPaper = false,
  });

  final DrawingController controller;
  final Offset origin;
  final bool darkPaper;

  @override
  State<SelectionLayer> createState() => _SelectionLayerState();
}

class _SelectionLayerState extends State<SelectionLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );
  String _key = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(SelectionLayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _appear.dispose();
    super.dispose();
  }

  void _onChange() {
    final key = (widget.controller.selectedIds.toList()..sort()).join('|');
    if (key == _key) return;
    _key = key;
    if (key.isEmpty) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _appear.value = 1;
    } else {
      _appear.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: SelectionPainter(
            widget.controller,
            widget.origin,
            widget.darkPaper,
            _appear,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class SelectionPainter extends CustomPainter {
  SelectionPainter(
    this.controller, [
    this.origin = Offset.zero,
    this.darkPaper = false,
    this.appear,
  ]) : super(repaint: Listenable.merge([controller, controller.live, ?appear]));

  final DrawingController controller;
  final Offset origin;
  final bool darkPaper;
  final Animation<double>? appear;

  static const Color _accent = Color(0xFF0A84FF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    _paintContent(canvas);
    canvas.restore();
  }

  void _paintContent(Canvas canvas) {
    final lasso = controller.lasso;
    if (lasso.length > 1) {
      final path = Path()..moveTo(lasso.first.x, lasso.first.y);
      for (final v in lasso.skip(1)) {
        path.lineTo(v.x, v.y);
      }
      canvas.drawPath(
        Path.from(path)..close(),
        Paint()..color = _accent.withValues(alpha: 0.08),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..isAntiAlias = true,
      );
    }

    if (!controller.hasSelection) return;

    if (controller.isTransformingSelection) {
      canvas.save();
      canvas.translate(controller.selectionDx, controller.selectionDy);
      for (final s in controller.selectedStrokes) {
        InkRenderer.paintStroke(
          canvas,
          points: controller.previewPoints(s),
          tool: s.tool,
          colorValue: PaperColors.inkFor(s.colorValue, darkPaper: darkPaper),
          width: s.width,
        );
      }
      canvas.restore();
    }

    final k = 1 / (controller.viewScale?.call() ?? 1.0).clamp(0.05, 20.0);
    final t = Curves.easeOutCubic.transform(
      (appear?.value ?? 1.0).clamp(0.0, 1.0),
    );

    final ends = controller.linearEnds;
    if (ends != null) {
      canvas.drawLine(
        Offset(ends.start.x, ends.start.y),
        Offset(ends.end.x, ends.end.y),
        Paint()
          ..color = _accent.withValues(alpha: 0.5 * t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * k
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final f = controller.selectionFrame;
      if (f == null) return;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          f.left,
          f.top,
          f.right,
          f.bottom,
        ).inflate(controller.framePadDoc),
        Radius.circular(10 * k),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = _accent.withValues(alpha: 0.08 * t),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = _accent.withValues(alpha: t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * k,
      );
    }

    final active = controller.activeHandle;
    for (final spot in controller.handleSpots) {
      _drawHandle(canvas, Offset(spot.x, spot.y), k, t, spot.handle == active);
    }
  }

  void _drawHandle(Canvas canvas, Offset c, double k, double t, bool active) {
    final r =
        DrawingController.handleDiameterPx /
        2 *
        k *
        (0.6 + 0.4 * t) *
        (active ? 1.25 : 1.0);
    canvas.drawCircle(
      c + Offset(0, 1 * k),
      r + 0.5 * k,
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, 0.28 * t)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * k),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: t),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _accent.withValues(alpha: t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * k,
    );
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.origin != origin ||
      oldDelegate.darkPaper != darkPaper ||
      oldDelegate.appear != appear;
}
