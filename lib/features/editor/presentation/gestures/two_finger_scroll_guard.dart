import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../domain/two_finger_intent.dart';
import 'stylus_gate.dart';

/// Drives [zoomEnabled] so two-finger scrolling never zooms.
/// When [onScroll] is set, two-finger scrolling is reported directly
/// (trackpad style) and [scrolling] is true while it runs.
class TwoFingerScrollGuard extends StatefulWidget {
  const TwoFingerScrollGuard({
    super.key,
    required this.zoomEnabled,
    required this.child,
    this.scrolling,
    this.onScroll,
    this.onScrollEnd,
  });

  final ValueNotifier<bool> zoomEnabled;
  final ValueNotifier<bool>? scrolling;

  /// Finger movement in screen pixels since the last call.
  final ValueChanged<Offset>? onScroll;

  /// Release velocity in pixels per second.
  final ValueChanged<Offset>? onScrollEnd;
  final Widget child;

  @override
  State<TwoFingerScrollGuard> createState() => _TwoFingerScrollGuardState();
}

class _TwoFingerScrollGuardState extends State<TwoFingerScrollGuard> {
  final Map<int, Offset> _touches = {};
  final TwoFingerIntentClassifier _classifier = TwoFingerIntentClassifier();
  VelocityTracker _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
  Offset _lastFocal = Offset.zero;

  void _set(bool value) {
    if (widget.zoomEnabled.value != value) widget.zoomEnabled.value = value;
  }

  void _setScrolling(bool value) {
    final s = widget.scrolling;
    if (s != null && s.value != value) s.value = value;
  }

  Offset get _focal {
    var sum = Offset.zero;
    for (final p in _touches.values) {
      sum += p;
    }
    return sum / _touches.length.toDouble();
  }

  void _beginTouchPair() {
    final p = _touches.values.toList();
    _classifier.beginTouch(ax: p[0].dx, ay: p[0].dy, bx: p[1].dx, by: p[1].dy);
    _lastFocal = _focal;
    _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
    _setScrolling(false);
    _set(false);
  }

  void _endScroll() {
    if (widget.scrolling?.value != true) return;
    _setScrolling(false);
    widget.onScrollEnd?.call(_tracker.getVelocity().pixelsPerSecond);
  }

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch || StylusGate.active.value) return;
    _touches[e.pointer] = e.position;
    if (_touches.length == 2) {
      _beginTouchPair();
    } else if (_touches.length > 2) {
      _endScroll();
      _set(true);
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.position;
    if (_touches.length != 2) return;
    final p = _touches.values.toList();
    final intent = _classifier.updateTouch(
      ax: p[0].dx,
      ay: p[0].dy,
      bx: p[1].dx,
      by: p[1].dy,
    );
    if (intent == TwoFingerIntent.zoom) {
      _set(true);
    } else if (intent == TwoFingerIntent.scroll && widget.onScroll != null) {
      final focal = _focal;
      _setScrolling(true);
      widget.onScroll!(focal - _lastFocal);
      _lastFocal = focal;
      _tracker.addPosition(e.timeStamp, focal);
    }
  }

  void _release(PointerEvent e) {
    if (_touches.remove(e.pointer) == null) return;
    _endScroll();
    _classifier.reset();
    if (_touches.isEmpty) {
      _set(true);
    } else if (_touches.length == 2) {
      _beginTouchPair();
    }
  }

  void _panZoomStart(PointerPanZoomStartEvent e) {
    _classifier.reset();
    _set(false);
  }

  void _panZoomUpdate(PointerPanZoomUpdateEvent e) {
    final intent = _classifier.updatePanZoom(
      panX: e.pan.dx,
      panY: e.pan.dy,
      scale: e.scale,
    );
    if (intent == TwoFingerIntent.zoom) _set(true);
  }

  void _panZoomEnd(PointerPanZoomEndEvent e) {
    _classifier.reset();
    _set(true);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _release,
    onPointerCancel: _release,
    onPointerPanZoomStart: _panZoomStart,
    onPointerPanZoomUpdate: _panZoomUpdate,
    onPointerPanZoomEnd: _panZoomEnd,
    child: widget.child,
  );
}
