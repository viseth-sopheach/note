import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Fires [onDoubleTap] after two quick one-finger taps. Uses raw pointer
/// events, so it never competes with drawing, pinch or pan.
///
/// A tap is a single touch pointer that lifts within 250 ms and moves at most
/// 24 px. The second tap must start within 300 ms and 30 px of the first.
class OneFingerDoubleTap extends StatefulWidget {
  const OneFingerDoubleTap({
    super.key,
    required this.onDoubleTap,
    required this.child,
  });

  final VoidCallback onDoubleTap;
  final Widget child;

  @override
  State<OneFingerDoubleTap> createState() => _OneFingerDoubleTapState();
}

class _OneFingerDoubleTapState extends State<OneFingerDoubleTap> {
  static const Duration _maxTapTime = Duration(milliseconds: 250);
  static const Duration _maxGap = Duration(milliseconds: 300);
  static const double _tapSlop = 24;
  static const double _doubleSlop = 30;

  final Map<int, Offset> _origins = {};
  Duration _downTime = Duration.zero;
  Offset _downPos = Offset.zero;
  Duration? _lastEnd;
  Offset? _lastPos;
  int _peak = 0;
  bool _valid = true;

  void _forgetFirstTap() {
    _lastEnd = null;
    _lastPos = null;
  }

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    if (_origins.isEmpty) {
      _downTime = e.timeStamp;
      _downPos = e.position;
      _peak = 0;
      _valid = true;
    }
    _origins[e.pointer] = e.position;
    if (_origins.length > _peak) _peak = _origins.length;
    if (_origins.length > 1) {
      _valid = false;
      _forgetFirstTap();
    }
  }

  void _move(PointerMoveEvent e) {
    final origin = _origins[e.pointer];
    if (origin != null && (e.position - origin).distance > _tapSlop) {
      _valid = false;
    }
  }

  void _up(PointerUpEvent e) {
    if (_origins.remove(e.pointer) == null || _origins.isNotEmpty) return;

    final now = e.timeStamp;
    final isTap = _valid && _peak == 1 && now - _downTime <= _maxTapTime;
    if (!isTap) {
      _forgetFirstTap();
      return;
    }

    final lastEnd = _lastEnd;
    final lastPos = _lastPos;
    if (lastEnd != null &&
        lastPos != null &&
        _downTime - lastEnd <= _maxGap &&
        (_downPos - lastPos).distance <= _doubleSlop) {
      _forgetFirstTap();
      widget.onDoubleTap();
    } else {
      _lastEnd = now;
      _lastPos = _downPos;
    }
  }

  void _cancel(PointerCancelEvent e) {
    _origins.remove(e.pointer);
    _valid = false;
    _forgetFirstTap();
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
