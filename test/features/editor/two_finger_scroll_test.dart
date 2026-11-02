import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/two_finger_intent.dart';
import 'package:quill_notes/features/editor/presentation/gestures/two_finger_scroll_guard.dart';

void main() {
  group('TwoFingerIntentClassifier', () {
    test('parallel vertical movement is scroll', () {
      final c = TwoFingerIntentClassifier()
        ..beginTouch(ax: 100, ay: 300, bx: 200, by: 300);
      expect(
        c.updateTouch(ax: 100.5, ay: 270, bx: 199.5, by: 270),
        TwoFingerIntent.scroll,
      );
    });

    test('spreading fingers is zoom', () {
      final c = TwoFingerIntentClassifier()
        ..beginTouch(ax: 100, ay: 300, bx: 200, by: 300);
      expect(
        c.updateTouch(ax: 80, ay: 300, bx: 220, by: 300),
        TwoFingerIntent.zoom,
      );
    });

    test('decision is locked', () {
      final c = TwoFingerIntentClassifier()
        ..beginTouch(ax: 100, ay: 300, bx: 200, by: 300);
      c.updateTouch(ax: 100, ay: 270, bx: 200, by: 270);
      expect(
        c.updateTouch(ax: 0, ay: 270, bx: 400, by: 270),
        TwoFingerIntent.scroll,
      );
    });

    test('touchpad: pan without scale is scroll, scale change is zoom', () {
      expect(
        (TwoFingerIntentClassifier()
              ..updatePanZoom(panX: 0, panY: -30, scale: 1.0))
            .intent,
        TwoFingerIntent.scroll,
      );
      expect(
        (TwoFingerIntentClassifier()
              ..updatePanZoom(panX: 0, panY: 0, scale: 1.1))
            .intent,
        TwoFingerIntent.zoom,
      );
    });
  });

  group('TwoFingerScrollGuard + InteractiveViewer', () {
    late TransformationController transform;
    late ValueNotifier<bool> zoomAllowed;

    Future<void> pump(WidgetTester tester) async {
      transform = TransformationController();
      zoomAllowed = ValueNotifier(true);
      addTearDown(transform.dispose);
      addTearDown(zoomAllowed.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: TwoFingerScrollGuard(
            zoomEnabled: zoomAllowed,
            child: ValueListenableBuilder<bool>(
              valueListenable: zoomAllowed,
              builder: (_, zoom, _) => InteractiveViewer(
                transformationController: transform,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.25,
                maxScale: 4,
                scaleEnabled: zoom,
                child: const SizedBox(width: 800, height: 4000),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('two-finger vertical drag scrolls and does not zoom', (
      tester,
    ) async {
      await pump(tester);
      final a = await tester.startGesture(
        const Offset(300, 400),
        pointer: 1,
        kind: PointerDeviceKind.touch,
      );
      final b = await tester.startGesture(
        const Offset(400, 400),
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );
      for (var i = 0; i < 12; i++) {
        final jitter = i.isEven ? 0.6 : -0.6;
        await a.moveBy(Offset(jitter, -20));
        await b.moveBy(Offset(-jitter, -20));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pump();

      expect(transform.value.getMaxScaleOnAxis(), closeTo(1.0, 1e-6));
      expect(transform.value.getTranslation().y, lessThan(-100));
      expect(zoomAllowed.value, isTrue);
    });

    testWidgets('pinch still zooms', (tester) async {
      await pump(tester);
      final a = await tester.startGesture(
        const Offset(350, 400),
        pointer: 1,
        kind: PointerDeviceKind.touch,
      );
      final b = await tester.startGesture(
        const Offset(450, 400),
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );
      for (var i = 0; i < 10; i++) {
        await a.moveBy(const Offset(-15, 0));
        await b.moveBy(const Offset(15, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();

      expect(transform.value.getMaxScaleOnAxis(), greaterThan(1.2));
    });
  });
}