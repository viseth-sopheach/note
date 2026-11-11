import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
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

  test('recolors only the selected shape and undo restores it', () {
    drawShape(StrokeTool.rectangle);
    final before = c.strokes[0].colorValue;
    drawShape(StrokeTool.line); // selected
    expect(c.canRecolorSelection, isTrue);

    c.changeSelectionColor(0xFFC62828);
    expect(c.strokes[0].colorValue, before);
    expect(c.strokes[1].colorValue, 0xFFC62828);

    c.undo();
    expect(c.strokes[1].colorValue, before);
  });

  test('ellipse center dot follows the new color', () {
    drawShape(StrokeTool.ellipse);
    c.changeSelectionColor(0xFF1E5AA8);
    expect(c.strokes, hasLength(2));
    expect(c.strokes.every((s) => s.colorValue == 0xFF1E5AA8), isTrue);
  });

  test('freehand strokes are never recolored', () {
    c.selectTool(StrokeTool.pen);
    c.beginStroke(pointer: 1, x: 0, y: 0, pressure: 1, timeMs: 0);
    c.endStroke(pointer: 1, x: 5, y: 5, pressure: 1, timeMs: 16);
    final before = c.strokes.single.colorValue;
    drawShape(StrokeTool.triangle);

    c.changeSelectionColor(0xFF2E7D32);
    expect(c.strokes.first.colorValue, before);
    expect(c.strokes.last.colorValue, 0xFF2E7D32);
  });
}
