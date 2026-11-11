import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';
import '../../domain/stroke.dart';
import '../../domain/stroke_point.dart';
import '../../domain/stroke_tool.dart';
import '../paper/paper_colors.dart';
import 'ink_renderer.dart';

// ---------------------------------------------------------------------------
// Committed strokes: baked into a ui.Picture, rebuilt only when strokes change
// ---------------------------------------------------------------------------

final class InkPictureCache {
  /// After this many incremental appends the picture is re-baked flat, so the
  /// nested display list never grows deep.
  static const int _maxAppends = 24;

  ui.Picture? _picture;
  int _version = -1;
  int _baked = 0;
  int _appends = 0;
  bool _dark = false;
  String _selKey = '';
  String? _lastId;

  ui.Picture pictureFor(DrawingController c, {required bool darkPaper}) {
    final strokes = c.strokes;
    final moving = c.isTransformingSelection;
    final selKey = moving ? (c.selectedIds.toList()..sort()).join('|') : '';
    final version = c.inkEpoch;
    final cur = _picture;

    if (cur != null &&
        version == _version &&
        darkPaper == _dark &&
        selKey == _selKey) {
      return cur;
    }

    // Typical case: exactly one stroke was appended at the end.
    final append =
        cur != null &&
        !moving &&
        _selKey.isEmpty &&
        darkPaper == _dark &&
        version == _version + 1 &&
        strokes.length == _baked + 1 &&
        _appends < _maxAppends &&
        (_baked == 0 || strokes[_baked - 1].id == _lastId);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (append) {
      canvas.drawPicture(cur);
      _paint(canvas, strokes.last, darkPaper);
      _appends++;
    } else {
      final skip = moving ? c.selectedIds : const <String>{};
      for (final s in strokes) {
        if (!skip.contains(s.id)) _paint(canvas, s, darkPaper);
      }
      _appends = 0;
    }
    final next = recorder.endRecording();
    cur?.dispose();

    _version = version;
    _baked = strokes.length;
    _lastId = strokes.isEmpty ? null : strokes.last.id;
    _dark = darkPaper;
    _selKey = selKey;
    return _picture = next;
  }

  static void _paint(Canvas canvas, Stroke s, bool dark) =>
      InkRenderer.paintStroke(
        canvas,
        points: s.points,
        tool: s.tool,
        colorValue: PaperColors.inkFor(s.colorValue, darkPaper: dark),
        width: s.width,
        fillColorValue: s.fillColorValue == null
            ? null
            : PaperColors.inkFor(s.fillColorValue!, darkPaper: dark),
      );

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }
}

class CommittedInkLayer extends StatefulWidget {
  const CommittedInkLayer({
    super.key,
    required this.controller,
    this.origin = Offset.zero,
    this.darkPaper = false,
  });

  final DrawingController controller;
  final Offset origin;
  final bool darkPaper;

  @override
  State<CommittedInkLayer> createState() => _CommittedInkLayerState();
}

class _CommittedInkLayerState extends State<CommittedInkLayer> {
  final InkPictureCache _cache = InkPictureCache();

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          isComplex: true, // hint: worth raster-caching
          willChange: false,
          size: Size.infinite,
          painter: CommittedInkPainter(
            widget.controller,
            cache: _cache,
            origin: widget.origin,
            darkPaper: widget.darkPaper,
          ),
        ),
      ),
    );
  }
}

class CommittedInkPainter extends CustomPainter {
  CommittedInkPainter(
    this.controller, {
    required this.cache,
    this.origin = Offset.zero,
    this.darkPaper = false,
  }) : super(repaint: controller);

  final DrawingController controller;
  final InkPictureCache cache;
  final Offset origin;
  final bool darkPaper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.drawPicture(cache.pictureFor(controller, darkPaper: darkPaper));
    canvas.restore();
  }

  @override
  bool shouldRepaint(CommittedInkPainter old) =>
      old.controller != controller ||
      old.origin != origin ||
      old.darkPaper != darkPaper ||
      old.cache != cache;
}

// ---------------------------------------------------------------------------
// Live stroke: incremental path, finished segments frozen into Pictures
// ---------------------------------------------------------------------------

final class LiveStrokeCache {
  /// Segments kept in the active Path before they are frozen.
  static const int _chunk = 48;

  final List<ui.Picture> _frozen = [];
  Path _path = Path();
  String? _id;
  int _next = 1;
  int _segments = 0;
  Offset _tail = Offset.zero;

  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  void reset() {
    for (final f in _frozen) {
      f.dispose();
    }
    _frozen.clear();
    _path = Path();
    _id = null;
    _next = 1;
    _segments = 0;
  }

  /// Same midpoint-quadratic geometry as InkRenderer, but each new point
  /// costs O(1) instead of rebuilding the whole path.
  void paintPen(
    Canvas canvas,
    String id,
    List<StrokePoint> pts,
    Color color,
    double width,
  ) {
    if (_id != id || pts.length < _next) {
      reset();
      _id = id;
      _tail = Offset(pts.first.x, pts.first.y);
      _path.moveTo(_tail.dx, _tail.dy);
    }
    _paint
      ..color = color
      ..strokeWidth = width;

    while (_next < pts.length - 1) {
      final p = pts[_next], q = pts[_next + 1];
      _tail = Offset((p.x + q.x) / 2, (p.y + q.y) / 2);
      _path.quadraticBezierTo(p.x, p.y, _tail.dx, _tail.dy);
      _next++;
      if (++_segments >= _chunk) _freeze();
    }

    for (final f in _frozen) {
      canvas.drawPicture(f);
    }
    canvas.drawPath(_path, _paint);
    canvas.drawLine(_tail, Offset(pts.last.x, pts.last.y), _paint);
  }

  void _freeze() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawPath(_path, _paint);
    _frozen.add(recorder.endRecording());
    _path = Path()..moveTo(_tail.dx, _tail.dy);
    _segments = 0;
  }
}

class LiveInkLayer extends StatefulWidget {
  const LiveInkLayer({
    super.key,
    required this.controller,
    this.origin = Offset.zero,
    this.darkPaper = false,
  });

  final DrawingController controller;
  final Offset origin;
  final bool darkPaper;

  @override
  State<LiveInkLayer> createState() => _LiveInkLayerState();
}

class _LiveInkLayerState extends State<LiveInkLayer> {
  final LiveStrokeCache _cache = LiveStrokeCache();

  @override
  void dispose() {
    _cache.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          willChange: true,
          size: Size.infinite,
          painter: LiveInkPainter(
            widget.controller,
            cache: _cache,
            origin: widget.origin,
            darkPaper: widget.darkPaper,
          ),
        ),
      ),
    );
  }
}

class LiveInkPainter extends CustomPainter {
  LiveInkPainter(
    this.controller, {
    required this.cache,
    this.origin = Offset.zero,
    this.darkPaper = false,
  }) : super(repaint: controller.live);

  final DrawingController controller;
  final LiveStrokeCache cache;
  final Offset origin;
  final bool darkPaper;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = controller.livePoints;
    if (pts.isEmpty) {
      cache.reset(); // stroke finished or cancelled: free the pictures
      return;
    }

    final color = Color(
      PaperColors.inkFor(controller.colorValue, darkPaper: darkPaper),
    );
    final id = controller.liveStrokeId;

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    // Incremental path is valid only for the raw pen stroke. Highlighter
    // (alpha overlap), shape drags and snapped shapes use the full renderer.
    if (controller.tool == StrokeTool.pen &&
        id != null &&
        controller.recognizedShape == null &&
        pts.length >= 2) {
      cache.paintPen(canvas, id, pts, color, controller.width);
    } else {
      cache.reset();
      InkRenderer.paintStroke(
        canvas,
        points: pts,
        tool: controller.tool,
        colorValue: color.toARGB32(),
        width: controller.width,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LiveInkPainter old) =>
      old.controller != controller ||
      old.origin != origin ||
      old.darkPaper != darkPaper ||
      old.cache != cache;
}
