import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  late DrawingController c;
  var n = 0;

  setUp(() {
    n = 0;
    c = DrawingController(idGenerator: () => 'id${n++}');
  });

  tearDown(() => c.dispose());

  void drawLine(double y) {
    c.beginStroke(pointer: 1, x: 0, y: y, pressure: 1, timeMs: 0);
    c.endStroke(pointer: 1, x: 100, y: y, pressure: 1, timeMs: 16);
  }

  void eraseDrag(double x1, double y1, double x2, double y2) {
    c.beginStroke(pointer: 2, x: x1, y: y1, pressure: 1, timeMs: 100);
    c.endStroke(pointer: 2, x: x2, y: y2, pressure: 1, timeMs: 116);
  }

  test('erasing removes only the touched stroke', () {
    drawLine(0);
    drawLine(100);
    c.selectTool(StrokeTool.eraser);

    eraseDrag(50, -5, 50, 5);

    expect(c.strokes.map((s) => s.id), ['id1']);
  });

  test('one drag over two strokes is one undo step', () {
    drawLine(0);
    drawLine(30);
    c.selectTool(StrokeTool.eraser);

    eraseDrag(50, -5, 50, 40);
    expect(c.strokes, isEmpty);

    c.undo();
    expect(c.strokes.map((s) => s.id), ['id0', 'id1']);

    c.redo();
    expect(c.strokes, isEmpty);
  });

  test('erasing changes the revision so autosave runs', () {
    drawLine(0);
    final before = c.revision;
    c.selectTool(StrokeTool.eraser);

    eraseDrag(50, -5, 50, 5);

    expect(c.revision, greaterThan(before));
  });

  test('a drag that touches nothing changes nothing', () {
    drawLine(0);
    final before = c.revision;
    c.selectTool(StrokeTool.eraser);

    eraseDrag(50, 200, 60, 200);

    expect(c.strokes, hasLength(1));
    expect(c.revision, before);
    c.undo();
    expect(c.strokes, isEmpty); // undid the original line, not an erase
  });

  test('cancel restores erased strokes', () {
    drawLine(0);
    c.selectTool(StrokeTool.eraser);

    c.beginStroke(pointer: 2, x: 50, y: -5, pressure: 1, timeMs: 100);
    c.extendStroke(pointer: 2, x: 50, y: 5, pressure: 1, timeMs: 108);
    expect(c.strokes, isEmpty);

    c.cancelStroke(2);

    expect(c.strokes, hasLength(1));
    expect(c.isDrawing, isFalse);
  });
}