import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/presentation/drawing/drawing_surface.dart';
import 'package:quill_notes/features/editor/presentation/gestures/one_finger_double_tap.dart';

void main() {
  late DrawingController c;

  setUp(() => c = DrawingController(idGenerator: () => 'id'));
  tearDown(() => c.dispose());

  Future<void> pump(WidgetTester tester, VoidCallback onDouble) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: OneFingerDoubleTap(
            onDoubleTap: onDouble,
            child: DrawingSurface(
              controller: c,
              allowTouch: true,
              child: const SizedBox(width: 300, height: 300),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('double tap with one finger undoes the last stroke', (
    tester,
  ) async {
    await pump(tester, c.undo);

    c.beginStroke(pointer: 90, x: 0, y: 0, pressure: 1, timeMs: 0);
    c.endStroke(pointer: 90, x: 80, y: 0, pressure: 1, timeMs: 16);
    expect(c.strokes, hasLength(1));

    await tester.tapAt(const Offset(150, 150));
    await tester.tapAt(const Offset(152, 151));
    await tester.pump();

    expect(c.strokes, isEmpty);
  });

  testWidgets('two taps far apart do not undo', (tester) async {
    var count = 0;
    await pump(tester, () => count++);

    await tester.tapAt(const Offset(20, 20));
    await tester.tapAt(const Offset(250, 250));
    await tester.pump();

    expect(count, 0);
  });

  testWidgets('a finger tap leaves no stroke', (tester) async {
    await pump(tester, () {});

    await tester.tapAt(const Offset(100, 100));
    await tester.pump();

    expect(c.strokes, isEmpty);
    expect(c.isDrawing, isFalse);
  });
}
