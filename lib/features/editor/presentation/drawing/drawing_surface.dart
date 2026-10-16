import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';

/// Captures mouse, stylus and (optionally) finger input and sends it to
/// [controller].
///
/// Place this INSIDE the zoomed and panned content. [origin] is where the
/// paper corner is inside this widget, so points are reported relative to
/// the paper (negative values are outside the paper).
/// When [allowTouch] is false, finger touch is ignored so it can pan and
/// zoom the page. When it is true, one finger draws and a second finger
/// cancels the stroke so pinch zoom still works.
class DrawingSurface extends StatefulWidget {
  const DrawingSurface({
    super.key,
    required this.controller,
    required this.child,
    this.allowTouch = false,
    this.origin = Offset.zero,
  });

  final DrawingController controller;
  final Widget child;
  final bool allowTouch;
  final Offset origin;

  @override
  State<DrawingSurface> createState() => _DrawingSurfaceState();
}

class _DrawingSurfaceState extends State<DrawingSurface> {
  final Set<int> _touches = {};
  int? _drawingPointer;

  DrawingController get _c => widget.controller;

  Offset _local(PointerEvent e) => e.localPosition - widget.origin;

  bool _isDrawingDevice(PointerEvent e) =>
      e.kind == PointerDeviceKind.mouse ||
      e.kind == PointerDeviceKind.stylus ||
      (widget.allowTouch && e.kind == PointerDeviceKind.touch);

  static double _pressure(PointerEvent e) {
    if (e.kind != PointerDeviceKind.stylus) return 1.0;
    final range = e.pressureMax - e.pressureMin;
    if (range <= 0) return 1.0;
    return ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0);
  }

  void _down(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.touch) {
      _touches.add(e.pointer);
      if (_touches.length > 1) {
        final active = _drawingPointer;
        if (active != null) {
          _c.cancelStroke(active);
          _drawingPointer = null;
        }
        return;
      }
    }
    if (!_isDrawingDevice(e)) return;
    if (e.kind == PointerDeviceKind.mouse &&
        (e.buttons & kPrimaryButton) == 0) {
      return;
    }
    final p = _local(e);
    final started = _c.beginStroke(
      pointer: e.pointer,
      x: p.dx,
      y: p.dy,
      pressure: _pressure(e),
      timeMs: e.timeStamp.inMilliseconds,
    );
    if (started) _drawingPointer = e.pointer;
  }

  void _move(PointerMoveEvent e) {
    final p = _local(e);
    _c.extendStroke(
      pointer: e.pointer,
      x: p.dx,
      y: p.dy,
      pressure: _pressure(e),
      timeMs: e.timeStamp.inMilliseconds,
    );
  }

  void _up(PointerUpEvent e) {
    _touches.remove(e.pointer);
    if (e.pointer == _drawingPointer) _drawingPointer = null;
    final p = _local(e);
    _c.endStroke(
      pointer: e.pointer,
      x: p.dx,
      y: p.dy,
      pressure: _pressure(e),
      timeMs: e.timeStamp.inMilliseconds,
    );
  }

  void _cancel(PointerCancelEvent e) {
    _touches.remove(e.pointer);
    if (e.pointer == _drawingPointer) _drawingPointer = null;
    _c.cancelStroke(e.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: widget.child,
    );
  }
}
