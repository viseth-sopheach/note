import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Fires [onDoubleTap] after two quick two-finger taps. Uses raw pointer
/// events, so it never competes with pinch, pan or drawing.
class TwoFingerDoubleTap extends StatefulWidget {
  const TwoFingerDoubleTap({
    super.key,
    required this.onDoubleTap,
    required this.child,
  });

  final VoidCallback onDoubleTap;
  final Widget child;

  @override
  State<TwoFingerDoubleTap> createState() => _TwoFingerDoubleTapState();
}

class _TwoFingerDoubleTapState extends State<TwoFingerDoubleTap> {
  static const Duration _maxTapTime = Duration(milliseconds: 300);
  static const Duration _maxGap = Duration(milliseconds: 450);
  static const double _slop = 24;

  final Map<int, Offset> _origins = {};
  Duration _firstDown = Duration.zero;
  Duration? _lastTapEnd;
  int _peak = 0;
  bool _valid = true;

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    if (_origins.isEmpty) {
      _firstDown = e.timeStamp;
      _peak = 0;
      _valid = true;
    }
    _origins[e.pointer] = e.position;
    _peak = math.max(_peak, _origins.length);
    if (_origins.length > 2) _valid = false;
  }

  void _move(PointerMoveEvent e) {
    final origin = _origins[e.pointer];
    if (origin != null && (e.position - origin).distance > _slop) {
      _valid = false; // a pinch or pan, not a tap
    }
  }

  void _up(PointerUpEvent e) {
    if (_origins.remove(e.pointer) == null || _origins.isNotEmpty) return;
    final now = e.timeStamp;
    final isTap = _valid && _peak == 2 && now - _firstDown <= _maxTapTime;
    if (!isTap) {
      _lastTapEnd = null;
      return;
    }
    final last = _lastTapEnd;
    if (last != null && now - last <= _maxGap) {
      _lastTapEnd = null;
      widget.onDoubleTap();
    } else {
      _lastTapEnd = now;
    }
  }

  void _cancel(PointerCancelEvent e) {
    _origins.remove(e.pointer);
    _valid = false;
    _lastTapEnd = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _cancel,
    child: widget.child,
  );
}