import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../domain/shape_geometry.dart';

enum MeasureKind { none, ruler, protractor }

/// Position and rotation of the ruler or protractor, in scene coordinates
/// (the zoomed content of the editor).
class MeasureController extends ChangeNotifier {
  static const double cm = 96 / 2.54; // 96 dpi page units per centimetre
  static const double rulerLength = cm * 16;
  static const double rulerThickness = 64;
  static const double protractorRadius = 180;
  static const double handleSize = 30;

  static const double _snapStep = math.pi / 12;
  static const double _snapTolerance = 0.026; // about 1.5 degrees

  MeasureKind _kind = MeasureKind.none;
  double _cx = 0;
  double _cy = 0;
  double _angle = 0;
  double _rawAngle = 0;
  bool _interacting = false;

  MeasureKind get kind => _kind;
  bool get visible => _kind != MeasureKind.none;
  bool get interacting => _interacting;
  double get cx => _cx;
  double get cy => _cy;
  double get angle => _angle;

  /// Angle of the base edge, 0 to 180.
  double get degrees => (_angle * 180 / math.pi) % 180;

  double get handleReach =>
      (_kind == MeasureKind.protractor ? protractorRadius : rulerLength / 2) -
      handleSize / 2 -
      6;

  /// Shows [kind] at (x, y), or hides it when it is already shown.
  void toggle(MeasureKind kind, {required double x, required double y}) {
    if (_kind == kind) {
      _kind = MeasureKind.none;
    } else {
      if (_kind == MeasureKind.none) {
        _cx = x;
        _cy = y;
      }
      _kind = kind;
    }
    _interacting = false;
    notifyListeners();
  }

  void beginInteraction() {
    _interacting = true;
    notifyListeners();
  }

  void endInteraction() {
    _interacting = false;
    notifyListeners();
  }

  void translate(double dx, double dy) {
    _cx += dx;
    _cy += dy;
    notifyListeners();
  }

  /// Drags one rotation handle by (dx, dy) scene units.
  void rotateByHandle(double dx, double dy, {required bool leading}) {
    final sign = leading ? -1.0 : 1.0;
    final reach = handleReach;
    final ex = _cx + math.cos(_rawAngle) * reach * sign + dx;
    final ey = _cy + math.sin(_rawAngle) * reach * sign + dy;
    var a = math.atan2(ey - _cy, ex - _cx);
    if (leading) a += math.pi;
    _rawAngle = _wrap(a);
    _angle = _snapAngle(_rawAngle);
    notifyListeners();
  }

  static double _wrap(double a) {
    var r = a % (2 * math.pi);
    if (r > math.pi) r -= 2 * math.pi;
    return r;
  }

  static double _snapAngle(double a) {
    final snapped = (a / _snapStep).roundToDouble() * _snapStep;
    return (a - snapped).abs() <= _snapTolerance ? _wrap(snapped) : a;
  }

  /// Edges a pen stroke can snap to, in scene coordinates.
  List<Segment> edgesInScene() {
    if (_kind == MeasureKind.none) return const [];
    final dx = math.cos(_angle);
    final dy = math.sin(_angle);
    final nx = -dy;
    final ny = dx;

    if (_kind == MeasureKind.ruler) {
      final hl = rulerLength / 2;
      final ht = rulerThickness / 2;
      Segment edge(double side) => (
        ax: _cx - dx * hl + nx * ht * side,
        ay: _cy - dy * hl + ny * ht * side,
        bx: _cx + dx * hl + nx * ht * side,
        by: _cy + dy * hl + ny * ht * side,
      );
      return [edge(1), edge(-1)];
    }

    const r = protractorRadius;
    return [
      (ax: _cx - dx * r, ay: _cy - dy * r, bx: _cx + dx * r, by: _cy + dy * r),
    ];
  }

  /// Same edges, relative to [origin] (the paper corner of a page).
  List<Segment> edgesRelativeTo(Offset origin) => [
    for (final s in edgesInScene())
      (
        ax: s.ax - origin.dx,
        ay: s.ay - origin.dy,
        bx: s.bx - origin.dx,
        by: s.by - origin.dy,
      ),
  ];
}
