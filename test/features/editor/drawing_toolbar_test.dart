import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';
import 'package:quill_notes/features/editor/presentation/toolbar/drawing_toolbar.dart';

void main() {
  late DrawingController c;

  setUp(() => c = DrawingController(idGenerator: () => 'id'));
  tearDown(() => c.dispose());

  Future<void> pumpToolbar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(3200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DrawingToolbar(controller: c)),
      ),
    );
  }

  testWidgets('selecting highlighter changes the tool and default width', (
    tester,
  ) async {
    await pumpToolbar(tester);

    await tester.tap(find.text('Highlighter'));
    await tester.pump();

    expect(c.tool, StrokeTool.highlighter);
    expect(c.width, 3);
  });

  testWidgets('selecting a color updates the controller', (tester) async {
    await pumpToolbar(tester);

    await tester.tap(find.byTooltip('Red'));
    await tester.pump();

    expect(c.colorValue, 0xFFC62828);
  });

  testWidgets('selecting a width updates the controller', (tester) async {
    await pumpToolbar(tester);

    await tester.tap(find.byTooltip('Width 4'));
    await tester.pump();

    expect(c.width, 4);
  });

  test('settings cannot change while drawing', () {
    c.beginStroke(pointer: 1, x: 0, y: 0, pressure: 1, timeMs: 0);
    c.selectTool(StrokeTool.highlighter);
    c.selectColor(0xFFC62828);
    c.selectWidth(6);

    expect(c.tool, StrokeTool.pen);
    expect(c.colorValue, 0xFF1B1B1F);
    expect(c.width, 2);
  });
}
