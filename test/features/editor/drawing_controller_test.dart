import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';

void main() {
  late DrawingController c;
  var n = 0;

  setUp(() {
    n = 0;
    c = DrawingController(idGenerator: () => 'id${n++}');
  });

  tearDown(() => c.dispose());

  void begin(int pointer, {int t = 100}) => c.beginStroke(
        pointer: pointer,
        x: 0,
        y: 0,
        pressure: 1,
        timeMs: t,
      );

  test('draws a stroke with times relative to the start', () {
    begin(1, t: 100);
    c.extendStroke(pointer: 1, x: 10, y: 0, pressure: 0.5, timeMs: 116);
    c.endStroke(pointer: 1, x: 20, y: 0, pressure: 0.5, timeMs: 132);

    expect(c.isDrawing, isFalse);
    expect(c.strokes, hasLength(1));
    final points = c.strokes.single.points;
    expect(points.map((p) => p.timestampMs), [0, 16, 32]);
    expect(c.strokes.single.id, 'id0');
  });

  test('ignores a second pointer while drawing', () {
    begin(1);
    expect(
      c.beginStroke(pointer: 2, x: 5, y: 5, pressure: 1, timeMs: 110),
      isFalse,
    );
    c.endStroke(pointer: 2, x: 9, y: 9, pressure: 1, timeMs: 120);
    expect(c.isDrawing, isTrue);
    expect(c.strokes, isEmpty);
  });

  test('cancel drops the stroke', () {
    begin(1);
    c.cancelStroke(1);
    expect(c.isDrawing, isFalse);
    expect(c.strokes, isEmpty);
  });

  test('notifies on begin and end, live on accepted points', () {
    var committed = 0;
    var live = 0;
    c.addListener(() => committed++);
    c.live.addListener(() => live++);

    begin(1);
    c.extendStroke(pointer: 1, x: 10, y: 0, pressure: 1, timeMs: 116);
    c.endStroke(pointer: 1, x: 10, y: 0, pressure: 1, timeMs: 120);

    expect(committed, 2);
    expect(live, 3);
  });
}