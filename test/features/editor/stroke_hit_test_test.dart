import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_hit_test.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  Stroke line({StrokeTool tool = StrokeTool.pen, double width = 2}) => Stroke(
        id: 's',
        tool: tool,
        colorValue: 0xFF000000,
        width: width,
        points: const [
          StrokePoint(x: 0, y: 0),
          StrokePoint(x: 100, y: 0),
        ],
      );

  bool hit(Stroke s, double ax, double ay, double bx, double by, double r) =>
      StrokeHitTest.hitsSegment(s, ax: ax, ay: ay, bx: bx, by: by, radius: r);

  test('a segment crossing the stroke hits', () {
    expect(hit(line(), 50, -5, 50, 5, 0), isTrue);
  });

  test('a segment far from the stroke misses', () {
    expect(hit(line(), 50, 20, 60, 20, 5), isFalse);
  });

  test('radius extends the reach', () {
    expect(hit(line(), 50, 8, 50, 8, 10), isTrue);
    expect(hit(line(), 50, 30, 50, 30, 10), isFalse);
  });

  test('a fast path across the stroke hits even without a point on it', () {
    expect(hit(line(), 40, 50, 40, -50, 1), isTrue);
  });

  test('a one-point stroke is hit by a nearby point', () {
    final dot = Stroke(
      id: 'dot',
      tool: StrokeTool.pen,
      colorValue: 0xFF000000,
      width: 2,
      points: const [StrokePoint(x: 5, y: 5)],
    );
    expect(hit(dot, 8, 5, 8, 5, 5), isTrue);
    expect(hit(dot, 50, 50, 50, 50, 5), isFalse);
  });

  test('a highlighter is wider to hit than a pen', () {
    expect(hit(line(), 50, 15, 50, 15, 5), isFalse);
    expect(
      hit(line(tool: StrokeTool.highlighter, width: 3), 50, 8, 50, 8, 5),
      isTrue,
    );
  });
}