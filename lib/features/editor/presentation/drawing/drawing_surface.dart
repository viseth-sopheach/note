import 'dart:async';

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
///
/// Every pointer is reported with full pressure (1.0). Pen width is driven
/// by [DrawingController] settings, not by raw device pressure, so the ink
/// is identical for mouse, stylus and finger.
class DrawingSurface extends StatefulWidget {
  const DrawingSurface({
    super.key,
    required this.controller,
    required this.child,
    this.allowTouch = false,
    this.origin = Offset.zero,
    this.bounds,
    this.isClaimed,
    this.onTap,
    this.onLongPress,
    this.longPressDuration = const Duration(seconds: 1),
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

  /// Called on a quick tap. Return true to consume it (no dot is drawn).
  final bool Function(Offset paperPoint)? onTap;

  /// Called when the pointer is held still at [paperPoint] for
  /// [longPressDuration]. The in-flight stroke is cancelled before this
  /// fires, so no ink is committed. [globalPosition] is the raw pointer
  /// position for showing a menu at the touch point.
  final void Function(Offset paperPoint, Offset globalPosition)? onLongPress;

  /// How long the pointer must be held still before [onLongPress] fires.
  final Duration longPressDuration;

  @override
  State<DrawingSurface> createState() => _DrawingSurfaceState();
}

class _DrawingSurfaceState extends State<DrawingSurface> {
  final Set<int> _touches = {};
  int? _drawingPointer;

  Offset? _downPos;
  int _downMs = 0;

  Timer? _lpTimer;

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

  /// Always report full pressure. Pen width is a user setting, not a
  /// function of device pressure, so every input kind draws the same line.
  static double _pressure(PointerEvent e) => 1.0;

  void _hover(PointerHoverEvent e) {
    final p = _local(e);
    final b = widget.bounds;
    if (b != null && !b.contains(p)) {
      _c.clearHover();
      return;
    }
    _c.hoverAt(p.dx, p.dy);
  }

  void _cancelLongPress() {
    _lpTimer?.cancel();
    _lpTimer = null;
  }

  void _armLongPress(int pointer, Offset paper, Offset global) {
    if (widget.onLongPress == null || !DrawingController.hasClipboard) return;
    _cancelLongPress();
    _lpTimer = Timer(widget.longPressDuration, () {
      _lpTimer = null;
      if (pointer != _drawingPointer) return;
      if (_c.isTransformingSelection ||
          _c.hitsSelectionChrome(paper.dx, paper.dy)) {
        return;
      }
      _c.cancelStroke(pointer);
      _drawingPointer = null;
      _downPos = null;
      widget.onLongPress!(paper, global);
    });
  }

  @override
  void dispose() {
    _cancelLongPress();
    super.dispose();
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
        _cancelLongPress();
        return;
      }
    }
    if (!_isDrawingDevice(e)) return;
    if (e.kind == PointerDeviceKind.mouse &&
        (e.buttons & kPrimaryButton) == 0) {
      return;
    }

    // Reject strokes that start outside the defined bounds.
    final raw = _local(e);
    final b = widget.bounds;
    if (b != null && !b.contains(raw)) return;
    if (widget.isClaimed?.call(raw) ?? false) return;
    final p = raw;

    final started = _c.beginStroke(
      pointer: e.pointer,
      x: p.dx,
      y: p.dy,
      pressure: _pressure(e),
      timeMs: e.timeStamp.inMilliseconds,
    );
    if (started) {
      _drawingPointer = e.pointer;
      _downPos = raw;
      _downMs = e.timeStamp.inMilliseconds;
      _armLongPress(e.pointer, raw, e.position);
    }
  }

  void _move(PointerMoveEvent e) {
    final b = widget.bounds;
    if (b != null && !b.contains(_local(e))) return;

    // A real drag is not a long press. Check before forwarding so the timer
    // does not fire on the same frame as the first move.
    final d0 = _downPos;
    if (d0 != null &&
        e.pointer == _drawingPointer &&
        (_local(e) - d0).distance > 10) {
      _cancelLongPress();
    }

    // Clamp movement coordinates to keep strokes bounded on the paper.
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
    _cancelLongPress();
    _touches.remove(e.pointer);
    final wasDrawing = e.pointer == _drawingPointer;
    if (wasDrawing) _drawingPointer = null;

    final down = _downPos;
    _downPos = null;
    if (wasDrawing &&
        down != null &&
        widget.onTap != null &&
        (_local(e) - down).distance <= 6 &&
        e.timeStamp.inMilliseconds - _downMs <= 350 &&
        widget.onTap!(_local(e))) {
      _c.cancelStroke(e.pointer);
      return;
    }

    // endStroke turns a quick tap into a select / deselect with no dot.
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
    _cancelLongPress();
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
      child: MouseRegion(
        onHover: _hover,
        onExit: (_) => _c.clearHover(),
        child: _child,
      ),
    );
  }

  Widget get _child => widget.child;
}
