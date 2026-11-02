import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../domain/two_finger_intent.dart';

/// Drives [zoomEnabled] so two-finger scrolling never zooms.
/// Idle: true. Two-finger gesture: false until it is classified as a pinch.
/// Uses raw pointer events, so it never competes in the gesture arena.
class TwoFingerScrollGuard extends StatefulWidget {
  const TwoFingerScrollGuard({
    super.key,
    required this.zoomEnabled,
    required this.child,
  });

  final ValueNotifier<bool> zoomEnabled;
  final Widget child;

  @override
  State<TwoFingerScrollGuard> createState() => _TwoFingerScrollGuardState();
}

class _TwoFingerScrollGuardState extends State<TwoFingerScrollGuard> {
  final Map<int, Offset> _touches = {};
  final TwoFingerIntentClassifier _classifier = TwoFingerIntentClassifier();

  void _set(bool value) {
    if (widget.zoomEnabled.value != value) widget.zoomEnabled.value = value;
  }

  void _beginTouchPair() {
    final p = _touches.values.toList();
    _classifier.beginTouch(ax: p[0].dx, ay: p[0].dy, bx: p[1].dx, by: p[1].dy);
    _set(false);
  }

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    _touches[e.pointer] = e.position;
    if (_touches.length == 2) {
      _beginTouchPair();
    } else if (_touches.length > 2) {
      _set(true);
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.position;
    if (_touches.length != 2) return;
    final p = _touches.values.toList();
    final intent = _classifier.updateTouch(
      ax: p[0].dx, ay: p[0].dy, bx: p[1].dx, by: p[1].dy,
    );
    if (intent == TwoFingerIntent.zoom) _set(true);
  }

  void _release(PointerEvent e) {
    if (_touches.remove(e.pointer) == null) return;
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
      panX: e.pan.dx, panY: e.pan.dy, scale: e.scale,
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