import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  Stroke sample({List<StrokePoint>? points}) => Stroke(
    id: 's1',
    tool: StrokeTool.pen,
    colorValue: 0xFF1B1B1F,
    width: 2,
    points:
        points ??
        const [
          StrokePoint(x: 1, y: 2, pressure: 0.5, timestampMs: 0),
          StrokePoint(x: 3, y: 4, pressure: 0.7, timestampMs: 16),
        ],
  );

  test('strokes with the same data are equal', () {
    expect(sample(), sample());
    expect(sample().hashCode, sample().hashCode);
  });

  test('a different point makes strokes unequal', () {
    final other = sample(points: const [StrokePoint(x: 9, y: 9)]);
    expect(sample(), isNot(other));
  });

  test('points list cannot be modified', () {
    final stroke = sample();
    expect(
      () => stroke.points.add(const StrokePoint(x: 0, y: 0)),
      throwsUnsupportedError,
    );
  });

  test('copyWith keeps the id and replaces given fields', () {
    final copy = sample().copyWith(tool: StrokeTool.highlighter, width: 12);
    expect(copy.id, 's1');
    expect(copy.tool, StrokeTool.highlighter);
    expect(copy.width, 12);
    expect(copy.points, sample().points);
  });

  test('point defaults are full pressure and time zero', () {
    const p = StrokePoint(x: 1, y: 1);
    expect(p.pressure, 1.0);
    expect(p.timestampMs, 0);
  });
}
