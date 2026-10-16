import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/presentation/drawing/ink_layers.dart';

void main() {
  testWidgets('layers render strokes and a live stroke without errors', (
    tester,
  ) async {
    final c = DrawingController(idGenerator: () => 'id');
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            children: [
              Positioned.fill(child: CommittedInkLayer(controller: c)),
              Positioned.fill(child: LiveInkLayer(controller: c)),
            ],
          ),
        ),
      ),
    );

    c.beginStroke(pointer: 1, x: 10, y: 10, pressure: 1, timeMs: 0);
    c.extendStroke(pointer: 1, x: 50, y: 40, pressure: 0.5, timeMs: 16);
    await tester.pump();
    c.endStroke(pointer: 1, x: 90, y: 60, pressure: 0.8, timeMs: 32);
    await tester.pump();

    expect(c.strokes, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
