import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/domain/stroke_codec.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DrawingController c;
  var n = 0;

  setUp(() {
    n = 0;
    c = DrawingController(idGenerator: () => 'id${n++}');
  });
  tearDown(() => c.dispose());

  void drawShape(StrokeTool t) {
    c.clearSelection();
    c.selectTool(t);
    c.beginStroke(pointer: 1, x: 0, y: 0, pressure: 1, timeMs: 0);
    c.endStroke(pointer: 1, x: 100, y: 80, pressure: 1, timeMs: 16);
  }

  test('fills only the selected shape with the chosen color', () {
    drawShape(StrokeTool.rectangle);
    drawShape(StrokeTool.triangle); // selected
    final border = c.strokes[1];

    c.highlightSelection(0xFFFFEB3B);
    expect(c.strokes[0].fillColorValue, isNull);
    expect(c.strokes[1].fillColorValue, 0xFFFFEB3B);
    expect(c.strokes[1].colorValue, border.colorValue);
    expect(c.strokes[1].width, border.width);
    expect(c.selectionFillColorValue, 0xFFFFEB3B);

    c.undo();
    expect(c.strokes[1].fillColorValue, isNull);
    c.redo();
    expect(c.strokes[1].fillColorValue, 0xFFFFEB3B);
  });

  test('fill color is independent of the border color', () {
    drawShape(StrokeTool.rectangle);
    c.highlightSelection(0xFFEF6C00);
    c.changeSelectionColor(0xFF1E5AA8);
    expect(c.strokes.single.colorValue, 0xFF1E5AA8);
    expect(c.strokes.single.fillColorValue, 0xFFEF6C00);
  });

  test('remove clears the fill and ellipse keeps its center dot', () {
    drawShape(StrokeTool.ellipse);
    c.highlightSelection(0xFF2E7D32);
    expect(c.strokes, hasLength(2));
    expect(c.strokes.first.filled, isTrue);
    expect(c.strokes.last.filled, isFalse);

    c.removeSelectionHighlight();
    expect(c.strokes.first.filled, isFalse);
  });

  test('lines cannot be highlighted', () {
    drawShape(StrokeTool.line);
    expect(c.canHighlightSelection, isFalse);
  });

  test('fill color survives save and load', () {
    drawShape(StrokeTool.rectangle);
    c.highlightSelection(0xFFC62828);
    final decoded = StrokeCodec.decode(StrokeCodec.encode(c.strokes));
    expect(decoded.single.fillColorValue, 0xFFC62828);
  });
}