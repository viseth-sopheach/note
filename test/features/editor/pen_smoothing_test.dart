import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';

double _noise(int i) {
  final n = math.sin(i * 12.9898) * 43758.5453;
  return (n - n.floorToDouble()) * 2 - 1;
}

double _maxTurn(List<({double x, double y})> p) {
  var worst = 0.0;
  for (var i = 2; i < p.length; i++) {
    final a = math.atan2(p[i - 1].y - p[i - 2].y, p[i - 1].x - p[i - 2].x);
    final b = math.atan2(p[i].y - p[i - 1].y, p[i].x - p[i - 1].x);
    var d = (b - a).abs();
    if (d > math.pi) d = 2 * math.pi - d;
    worst = math.max(worst, d);
  }
  return worst;
}

void main() {
  late DrawingController c;

  setUp(() => c = DrawingController(idGenerator: () => 'id'));
  tearDown(() => c.dispose());

  test('a noisy sine has no sharp turns after smoothing', () {
    final raw = [
      for (var i = 0; i < 100; i++)
        (x: i * 4.0, y: 300 + 80 * math.sin(i / 10) + _noise(i) * 1.5),
    ];

    c.beginStroke(
      pointer: 1,
      x: raw.first.x,
      y: raw.first.y,
      pressure: 1,
      timeMs: 0,
    );
    for (var i = 1; i < raw.length - 1; i++) {
      c.extendStroke(
        pointer: 1,
        x: raw[i].x,
        y: raw[i].y,
        pressure: 1,
        timeMs: i * 8,
      );
    }
    c.endStroke(
      pointer: 1,
      x: raw.last.x,
      y: raw.last.y,
      pressure: 1,
      timeMs: raw.length * 8,
    );

    final stroke = c.strokes.single;
    expect(stroke.points.first.x, raw.first.x); // first point stays raw
    expect(stroke.points.last.x, raw.last.x); // last point stays raw

    // The raw tail point is excluded from the turn measurement.
    final filtered = [
      for (final StrokePoint p in stroke.points.sublist(
        0,
        stroke.points.length - 1,
      ))
        (x: p.x, y: p.y),
    ];

    expect(_maxTurn(filtered), lessThan(_maxTurn(raw)));
    expect(_maxTurn(filtered), lessThan(1.0)); // radians, about 57 degrees
  });
}