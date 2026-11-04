import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/ink_geometry.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';

void main() {
  List<StrokePoint> timed() => [
    for (var i = 0; i < 40; i++)
      StrokePoint(x: i * 5.0, y: 0, timestampMs: i * 8),
  ];

  test('timed strokes use variable width and taper at both ends', () {
    final pts = timed();
    expect(InkGeometry.usesVariableWidth(pts), isTrue);
    final o = InkGeometry.build(pts, 4)!;
    expect(o.start.r, lessThan(2));
    expect(o.end.r, lessThan(2));
  });

  test('shape points (same time and pressure) keep a constant width', () {
    final pts = [
      for (var i = 0; i < 10; i++) StrokePoint(x: i * 5.0, y: i * 2.0),
    ];
    expect(InkGeometry.usesVariableWidth(pts), isFalse);
  });

  test('faster movement draws thinner', () {
    final slow = InkGeometry.build([
      for (var i = 0; i < 40; i++)
        StrokePoint(x: i * 1.0, y: 0, timestampMs: i * 16),
    ], 4)!;
    final fast = InkGeometry.build([
      for (var i = 0; i < 40; i++)
        StrokePoint(x: i * 20.0, y: 0, timestampMs: i * 8),
    ], 4)!;
    expect(fast.left[20].y.abs(), lessThan(slow.left[20].y.abs()));
  });
}
