import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// True while a stylus (Apple Pencil) is touching, hovering, or has just
/// lifted. Touch input is ignored during this time (palm rejection).
abstract final class StylusGate {
  static const Duration _linger = Duration(milliseconds: 700);
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);
  static final Set<int> _down = {};
  static Timer? _timer;

  static bool isStylus(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus ||
      e.kind == PointerDeviceKind.invertedStylus;

  static void _hold() {
    _timer?.cancel();
    _timer = null;
    active.value = true;
  }

  static void _release() {
    _timer?.cancel();
    _timer = Timer(_linger, () {
      _timer = null;
      if (_down.isEmpty) active.value = false;
    });
  }

  static void down(PointerDownEvent e) {
    if (!isStylus(e)) return;
    _down.add(e.pointer);
    _hold();
  }

  static void hover(PointerHoverEvent e) {
    if (!isStylus(e) || _down.isNotEmpty) return;
    _hold();
    _release();
  }

  static void end(PointerEvent e) {
    if (!isStylus(e)) return;
    _down.remove(e.pointer);
    if (_down.isEmpty) _release();
  }
}