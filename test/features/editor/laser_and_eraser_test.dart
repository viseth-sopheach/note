import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/domain/page_layout.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  late DrawingController c;
  var n = 0;
  setUp(() {
    n = 0;
    c = DrawingController(idGenerator: () => 'id${n++}');
  });
  tearDown(() => c.dispose());

  test('laser leaves no stroke, no history, no revision', () {
    c.selectTool(StrokeTool.laser);
    c.beginStroke(pointer: 1, x: 0, y: 0, pressure: 1, timeMs: 0);
    c.extendStroke(pointer: 1, x: 10, y: 0, pressure: 1, timeMs: 8);
    expect(c.hasLaser, isTrue);
    c.endStroke(pointer: 1, x: 20, y: 0, pressure: 1, timeMs: 16);
    expect(c.strokes, isEmpty);
    expect(c.canUndo, isFalse);
    expect(c.revision, 0);
    expect(c.laserHead, isNull);
  });

  test('a bigger eraser reaches farther', () {
    c.beginStroke(pointer: 1, x: 0, y: 0, pressure: 1, timeMs: 0);
    c.endStroke(pointer: 1, x: 100, y: 0, pressure: 1, timeMs: 16);
    c.selectTool(StrokeTool.eraser);

    c.beginStroke(pointer: 2, x: 50, y: 25, pressure: 1, timeMs: 100);
    c.endStroke(pointer: 2, x: 50, y: 25, pressure: 1, timeMs: 116);
    expect(c.strokes, hasLength(1));

    c.selectEraserRadius(30);
    c.beginStroke(pointer: 3, x: 50, y: 25, pressure: 1, timeMs: 200);
    c.endStroke(pointer: 3, x: 50, y: 25, pressure: 1, timeMs: 216);
    expect(c.strokes, hasLength(2));
  });

  test('layout slots', () {
    expect(PageLayout.fromName('nope'), PageLayout.single);
    expect(PageLayout.doublePage.leading, 1);
    expect(PageLayout.dualPages.columns, 2);
  });
}