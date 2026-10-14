import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_recorder.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  void begin(StrokeRecorder r) => r.begin(
        id: 's1',
        tool: StrokeTool.pen,
        colorValue: 0xFF000000,
        width: 2,
        first: const StrokePoint(x: 0, y: 0),
      );

  test('records points and builds a stroke', () {
    final r = StrokeRecorder();
    begin(r);
    expect(r.add(const StrokePoint(x: 10, y: 0)), isTrue);
    final stroke = r.end();

    expect(stroke.id, 's1');
    expect(stroke.points, hasLength(2));
    expect(r.isActive, isFalse);
  });

  test('skips points closer than minDistance', () {
    final r = StrokeRecorder(minDistance: 1);
    begin(r);
    expect(r.add(const StrokePoint(x: 0.3, y: 0.3)), isFalse);
    expect(r.points, hasLength(1));
  });

  test('a single tap gives a one-point stroke', () {
    final r = StrokeRecorder();
    begin(r);
    expect(r.end().points, hasLength(1));
  });

  test('beginning twice throws', () {
    final r = StrokeRecorder();
    begin(r);
    expect(() => begin(r), throwsStateError);
  });

  test('add or end without begin throws', () {
    final r = StrokeRecorder();
    expect(() => r.add(const StrokePoint(x: 1, y: 1)), throwsStateError);
    expect(r.end, throwsStateError);
  });

  test('cancel discards the stroke', () {
    final r = StrokeRecorder();
    begin(r);
    r.cancel();
    expect(r.isActive, isFalse);
    expect(r.points, isEmpty);
  });
}