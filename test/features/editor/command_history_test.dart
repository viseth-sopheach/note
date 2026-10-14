import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/command_history.dart';
import 'package:quill_notes/features/editor/domain/drawing_command.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  Stroke stroke(String id) => Stroke(
        id: id,
        tool: StrokeTool.pen,
        colorValue: 0xFF000000,
        width: 2,
        points: const [StrokePoint(x: 1, y: 1)],
      );

  late CommandHistory history;
  late List<Stroke> strokes;

  setUp(() {
    history = CommandHistory(limit: 3);
    strokes = [];
  });

  test('execute applies the command', () {
    history.execute(AddStrokeCommand(stroke('a')), strokes);
    expect(strokes.map((s) => s.id), ['a']);
    expect(history.canUndo, isTrue);
    expect(history.canRedo, isFalse);
  });

  test('undo and redo move strokes back and forth', () {
    history.execute(AddStrokeCommand(stroke('a')), strokes);
    history.execute(AddStrokeCommand(stroke('b')), strokes);

    expect(history.undo(strokes), isTrue);
    expect(strokes.map((s) => s.id), ['a']);

    expect(history.redo(strokes), isTrue);
    expect(strokes.map((s) => s.id), ['a', 'b']);
  });

  test('a new command clears the redo stack', () {
    history.execute(AddStrokeCommand(stroke('a')), strokes);
    history.undo(strokes);
    history.execute(AddStrokeCommand(stroke('b')), strokes);

    expect(history.canRedo, isFalse);
    expect(strokes.map((s) => s.id), ['b']);
  });

  test('undo and redo on empty stacks return false', () {
    expect(history.undo(strokes), isFalse);
    expect(history.redo(strokes), isFalse);
  });

  test('history is limited', () {
    for (final id in ['a', 'b', 'c', 'd']) {
      history.execute(AddStrokeCommand(stroke(id)), strokes);
    }
    while (history.undo(strokes)) {}
    expect(strokes.map((s) => s.id), ['a']);
  });

  test('clear empties both stacks', () {
    history.execute(AddStrokeCommand(stroke('a')), strokes);
    history.undo(strokes);
    history.clear();
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
  });
}