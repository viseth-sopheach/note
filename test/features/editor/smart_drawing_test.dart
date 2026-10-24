import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';

void main() {
  late DrawingController c;

  setUp(
    () => c = DrawingController(
      idGenerator: () => 'id',
      refineDelay: const Duration(milliseconds: 20),
      holdDuration: const Duration(seconds: 30),
      autoRefine: true,
    ),
  );
  tearDown(() => c.dispose());

  void line() {
    c.beginStroke(pointer: 1, x: 0, y: 0, pressure: 1, timeMs: 0);
    c.endStroke(pointer: 1, x: 200, y: 0, pressure: 1, timeMs: 16);
  }

  test('a long arc is smoothed after the pause and undo restores it', () async {
    c.beginStroke(pointer: 1, x: 100, y: 300, pressure: 1, timeMs: 0);
    for (var i = 1; i < 40; i++) {
      c.extendStroke(
        pointer: 1,
        x: 100 + 5.0 * i,
        y: 300 - 120 * math.sin(math.pi * i / 40),
        pressure: 1,
        timeMs: i * 8,
      );
    }
    c.endStroke(pointer: 1, x: 300, y: 300, pressure: 1, timeMs: 400);
    final rough = c.strokes.single.points.length;

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(c.strokes.single.points.length, greaterThan(rough));
    expect(c.strokes.single.points.first.x, 100);
    expect(c.strokes.single.points.last.x, 300);

    c.undo();
    expect(c.strokes.single.points.length, rough);
  });

  test('a new stroke cancels the pending recognition', () async {
    c.beginStroke(pointer: 1, x: 100, y: 300, pressure: 1, timeMs: 0);
    for (var i = 1; i < 40; i++) {
      c.extendStroke(
        pointer: 1,
        x: 100 + 5.0 * i,
        y: 300 - 120 * math.sin(math.pi * i / 40),
        pressure: 1,
        timeMs: i * 8,
      );
    }
    c.endStroke(pointer: 1, x: 300, y: 300, pressure: 1, timeMs: 400);
    final rough = c.strokes.single.points.length;

    c.beginStroke(pointer: 2, x: 0, y: 0, pressure: 1, timeMs: 410);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    c.cancelStroke(2);

    expect(c.strokes.single.points.length, rough);
  });

  test('tap selects, corner handle resizes in one undo step', () {
    line();
    c.beginStroke(pointer: 2, x: 100, y: 0, pressure: 1, timeMs: 100);
    c.endStroke(pointer: 2, x: 100, y: 0, pressure: 1, timeMs: 120);
    expect(c.selectedIds, {'id'});
    expect(c.strokes, hasLength(1));

    c.beginStroke(pointer: 3, x: 208, y: 8, pressure: 1, timeMs: 200);
    expect(c.isResizingSelection, isTrue);
    c.extendStroke(pointer: 3, x: 308, y: 8, pressure: 1, timeMs: 210);
    c.endStroke(pointer: 3, x: 308, y: 8, pressure: 1, timeMs: 220);

    expect(c.strokes.single.points.last.x, closeTo(300, 0.01));
    c.undo();
    expect(c.strokes.single.points.last.x, 200);
    c.redo();
    expect(c.strokes.single.points.last.x, closeTo(300, 0.01));
  });

  test('tapping empty space deselects without drawing a dot', () {
    line();
    c.beginStroke(pointer: 2, x: 100, y: 0, pressure: 1, timeMs: 100);
    c.endStroke(pointer: 2, x: 100, y: 0, pressure: 1, timeMs: 120);
    expect(c.hasSelection, isTrue);

    c.beginStroke(pointer: 3, x: 500, y: 500, pressure: 1, timeMs: 200);
    c.endStroke(pointer: 3, x: 500, y: 500, pressure: 1, timeMs: 210);

    expect(c.hasSelection, isFalse);
    expect(c.strokes, hasLength(1));
  });
}
