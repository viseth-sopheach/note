import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  late DrawingController c;
  var n = 0;

  setUp(() {
    n = 0;
    c = DrawingController(idGenerator: () => 'id${n++}');
  });

  tearDown(() => c.dispose());

  void draw() {
    c.beginStroke(pointer: 1, x: 0, y: 0, pressure: 1, timeMs: 0);
    c.endStroke(pointer: 1, x: 10, y: 0, pressure: 1, timeMs: 16);
  }

  test('undo removes the last stroke and redo restores it', () {
    draw();
    draw();

    c.undo();
    expect(c.strokes.map((s) => s.id), ['id0']);
    expect(c.canRedo, isTrue);

    c.redo();
    expect(c.strokes.map((s) => s.id), ['id0', 'id1']);
  });

  test('undo and redo change the revision so autosave runs', () {
    draw();
    final before = c.revision;

    c.undo();
    expect(c.revision, greaterThan(before));

    final afterUndo = c.revision;
    c.redo();
    expect(c.revision, greaterThan(afterUndo));
  });

  test('undo is blocked while drawing', () {
    draw();
    c.beginStroke(pointer: 2, x: 0, y: 0, pressure: 1, timeMs: 100);

    expect(c.canUndo, isFalse);
    c.undo();
    expect(c.strokes, hasLength(1));
  });

  test('loading a page clears the history', () {
    draw();
    c.replaceStrokes([
      Stroke(
        id: 'loaded',
        tool: StrokeTool.pen,
        colorValue: 0xFF000000,
        width: 2,
        points: const [StrokePoint(x: 1, y: 1)],
      ),
    ]);

    expect(c.canUndo, isFalse);
    expect(c.canRedo, isFalse);
  });
}
