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
    this.bounds,
    this.isClaimed,
  });

  final DrawingController controller;
  final Widget child;
  final bool allowTouch;
  final Offset origin;

  /// Paper rectangle in paper coordinates. Input outside it is ignored.
  final Rect? bounds;

  /// Called with the pointer-down position in paper coordinates. Return true
  /// when something else (for example an image) owns the touch, so no stroke
  /// starts.
  final bool Function(Offset paperPoint)? isClaimed;

  @override
  State<DrawingSurface> createState() => _DrawingSurfaceState();
}

class _DrawingSurfaceState extends State<DrawingSurface> {
  final Set<int> _touches = {};
  int? _drawingPointer;

  DrawingController get _c => widget.controller;

  Offset _local(PointerEvent e) => e.localPosition - widget.origin;

  /// Clamps pointer coordinates to stay within the valid paper bounds if defined.
  Offset _clamped(PointerEvent e) {
    final p = _local(e);
    final b = widget.bounds;
    if (b == null) return p;
    return Offset(
      p.dx.clamp(b.left, b.right).toDouble(),
      p.dy.clamp(b.top, b.bottom).toDouble(),
    );
  }

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

    // Critical: Reject strokes that start outside the defined bounds
    final raw = _local(e);
    if (widget.isClaimed?.call(raw) ?? false) return;
    final b = widget.bounds;
    if (b != null && !b.contains(raw)) return;
    final p = raw;

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
    // Critical: Clamp movement coordinates to keep strokes bounded on the paper
    final p = _clamped(e);
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

    // Critical: Clamp end coordinates to maintain proper bounds integrity
    final p = _clamped(e);
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