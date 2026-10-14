import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';

/// Captures mouse and stylus input on the page and sends it to [controller].
///
/// Place this INSIDE the zoomed and panned content. Pointer positions are
/// then already in document coordinates, at any zoom level.
/// Finger touch is ignored here so it can pan and zoom the page.
class DrawingSurface extends StatelessWidget {
  const DrawingSurface({
    super.key,
    required this.controller,
    required this.child,
  });

  final DrawingController controller;
  final Widget child;

  static bool _isDrawingDevice(PointerEvent e) =>
      e.kind == PointerDeviceKind.mouse || e.kind == PointerDeviceKind.stylus;

  static double _pressure(PointerEvent e) {
    if (e.kind != PointerDeviceKind.stylus) return 1.0;
    final range = e.pressureMax - e.pressureMin;
    if (range <= 0) return 1.0;
    return ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (!_isDrawingDevice(e)) return;
        if (e.kind == PointerDeviceKind.mouse &&
            (e.buttons & kPrimaryButton) == 0) {
          return;
        }
        controller.beginStroke(
          pointer: e.pointer,
          x: e.localPosition.dx,
          y: e.localPosition.dy,
          pressure: _pressure(e),
          timeMs: e.timeStamp.inMilliseconds,
        );
      },
      onPointerMove: (e) => controller.extendStroke(
        pointer: e.pointer,
        x: e.localPosition.dx,
        y: e.localPosition.dy,
        pressure: _pressure(e),
        timeMs: e.timeStamp.inMilliseconds,
      ),
      onPointerUp: (e) => controller.endStroke(
        pointer: e.pointer,
        x: e.localPosition.dx,
        y: e.localPosition.dy,
        pressure: _pressure(e),
        timeMs: e.timeStamp.inMilliseconds,
      ),
      onPointerCancel: (e) => controller.cancelStroke(e.pointer),
      child: child,
    );
  }
}