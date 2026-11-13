import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_simplifier.dart';

void main() {
  test('collinear points collapse to the two ends', () {
    final pts = [for (var i = 0; i < 50; i++) StrokePoint(x: i * 3.0, y: 0)];
    final out = StrokeSimplifier.rdp(pts);
    expect(out, [pts.first, pts.last]);
  });

  test('a corner survives', () {
    final pts = [
      for (var i = 0; i <= 20; i++) StrokePoint(x: i * 5.0, y: 0),
      for (var i = 1; i <= 20; i++) StrokePoint(x: 100, y: i * 5.0),
    ];
    final out = StrokeSimplifier.rdp(pts);
    expect(out, hasLength(3));
    expect(out[1].x, 100);
    expect(out[1].y, 0);
  });

  test('pressure and time of kept points are preserved', () {
    final pts = [
      const StrokePoint(x: 0, y: 0, pressure: 0.2, timestampMs: 5),
      const StrokePoint(x: 10, y: 50, pressure: 0.9, timestampMs: 9),
      const StrokePoint(x: 20, y: 0, pressure: 0.4, timestampMs: 14),
    ];
    expect(StrokeSimplifier.rdp(pts)[1].pressure, 0.9);
  });
}
