import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/presentation/drawing/drawing_surface.dart';

void main() {
  late DrawingController c;

  setUp(() => c = DrawingController(idGenerator: () => 'id'));
  tearDown(() => c.dispose());

  Future<void> pumpSurface(WidgetTester tester, {required bool allowTouch}) {
    return tester.pumpWidget(
      Align(
        alignment: Alignment.topLeft,
        child: DrawingSurface(
          controller: c,
          allowTouch: allowTouch,
          child: const SizedBox(width: 300, height: 300),
        ),
      ),
    );
  }

  testWidgets('a finger draws when touch is allowed', (tester) async {
    await pumpSurface(tester, allowTouch: true);

    final g = await tester.startGesture(
      const Offset(50, 50),
      kind: PointerDeviceKind.touch,
    );
    await g.moveTo(const Offset(120, 120));
    await g.up();

    expect(c.strokes, hasLength(1));
  });

  testWidgets('a finger is ignored when touch is not allowed', (tester) async {
    await pumpSurface(tester, allowTouch: false);

    final g = await tester.startGesture(
      const Offset(50, 50),
      kind: PointerDeviceKind.touch,
    );
    await g.moveTo(const Offset(120, 120));
    await g.up();

    expect(c.strokes, isEmpty);
  });

  testWidgets('a second finger cancels the stroke', (tester) async {
    await pumpSurface(tester, allowTouch: true);

    final first = await tester.startGesture(
      const Offset(50, 50),
      kind: PointerDeviceKind.touch,
    );
    await first.moveTo(const Offset(80, 80));
    expect(c.isDrawing, isTrue);

    final second = await tester.startGesture(
      const Offset(200, 200),
      kind: PointerDeviceKind.touch,
      pointer: 2,
    );
    expect(c.isDrawing, isFalse);

    await first.up();
    await second.up();
    expect(c.strokes, isEmpty);
  });

  testWidgets('a mouse always draws', (tester) async {
    await pumpSurface(tester, allowTouch: false);

    final g = await tester.startGesture(
      const Offset(50, 50),
      kind: PointerDeviceKind.mouse,
    );
    await g.moveTo(const Offset(120, 120));
    await g.up();

    expect(c.strokes, hasLength(1));
  });
}
