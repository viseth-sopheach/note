import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/domain/shape_recognizer.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';

typedef _P = (double, double);

double _noise(int i) {
  final n = math.sin(i * 12.9898) * 43758.5453;
  return (n - n.floorToDouble()) * 2 - 1;
}

List<_P> _polygon(List<_P> v, {double noise = 2.5, int perSide = 40}) {
  final out = <_P>[];
  var k = 0;
  final all = [...v, v.first];
  for (var i = 0; i < all.length - 1; i++) {
    for (var j = 0; j < perSide; j++) {
      final t = j / perSide;
      out.add((
        all[i].$1 + (all[i + 1].$1 - all[i].$1) * t + _noise(k) * noise,
        all[i].$2 + (all[i + 1].$2 - all[i].$2) * t + _noise(k + 1000) * noise,
      ));
      k++;
    }
  }
  return out.sublist(0, out.length - 6); // Leave a small gap.
}

List<_P> _circle() => [
  for (var i = 0; i < 120; i++)
    (
      300 +
          100 *
              (1 + 0.05 * _noise(i)) *
              math.cos(0.7 + 2.1 * math.pi * i / 119),
      300 +
          100 *
              (1 + 0.05 * _noise(i)) *
              math.sin(0.7 + 2.1 * math.pi * i / 119),
    ),
];

List<_P> _line(_P a, _P b) => [
  for (var i = 0; i < 80; i++)
    (
      a.$1 + (b.$1 - a.$1) * i / 79 + _noise(i) * 1.5,
      a.$2 + (b.$2 - a.$2) * i / 79 + _noise(i + 500) * 1.5,
    ),
];

List<_P> _arrow() {
  const tip = (400.0, 200.0);
  final wing = [
    (tip.$1 - 40 * math.cos(0.5), tip.$2 - 40 * math.sin(0.5)),
    (tip.$1 - 40 * math.cos(-0.5), tip.$2 - 40 * math.sin(-0.5)),
  ];
  List<_P> seg(_P a, _P b) => [
    for (var i = 1; i <= 12; i++)
      (a.$1 + (b.$1 - a.$1) * i / 12, a.$2 + (b.$2 - a.$2) * i / 12),
  ];
  return [
    ..._line((100, 200), tip),
    ...seg(tip, wing[0]),
    ...seg(wing[0], tip),
    ...seg(tip, wing[1]),
  ];
}

List<StrokePoint> _pts(List<_P> p) => [
  for (final q in p) StrokePoint(x: q.$1, y: q.$2),
];

ShapeKind? _kind(List<_P> p) => ShapeRecognizer.recognize(_pts(p))?.kind;

void main() {
  group('ShapeRecognizer', () {
    test('straight line', () {
      expect(_kind(_line((100, 100), (400, 160))), ShapeKind.line);
    });

    test('a nearly horizontal line snaps to horizontal', () {
      final shape = ShapeRecognizer.recognize(
        _pts(_line((100, 100), (400, 110))),
      )!;
      expect(shape.points.first.y, shape.points.last.y);
    });

    test('circle', () => expect(_kind(_circle()), ShapeKind.circle));

    test('rectangle', () {
      expect(
        _kind(_polygon([(100, 100), (320, 100), (320, 230), (100, 230)])),
        ShapeKind.rectangle,
      );
    });

    test('square', () {
      expect(
        _kind(_polygon([(100, 100), (300, 100), (300, 300), (100, 300)])),
        ShapeKind.square,
      );
    });

    test('triangle', () {
      expect(
        _kind(_polygon([(200, 100), (330, 300), (80, 300)], perSide: 45)),
        ShapeKind.triangle,
      );
    });

    test('arrow', () => expect(_kind(_arrow()), ShapeKind.arrow));

    test('scribbles and tiny strokes are not recognized', () {
      final scribble = <_P>[];
      var x = 200.0, y = 200.0;
      for (var i = 0; i < 100; i++) {
        x += _noise(i + 3) * 25;
        y += _noise(i + 80) * 25;
        scribble.add((x, y));
      }
      expect(_kind(scribble), isNull);
      expect(_kind(_line((100, 100), (120, 100))), isNull);
    });
  });

  group('DrawingController hold to snap', () {
    late DrawingController c;
    const hold = Duration(milliseconds: 30);

    setUp(
      () => c = DrawingController(idGenerator: () => 'id', holdDuration: hold),
    );
    tearDown(() => c.dispose());

    Future<void> drawAndHold(List<_P> path) async {
      c.beginStroke(
        pointer: 1,
        x: path.first.$1,
        y: path.first.$2,
        pressure: 1,
        timeMs: 0,
      );
      for (var i = 1; i < path.length; i++) {
        c.extendStroke(
          pointer: 1,
          x: path[i].$1,
          y: path[i].$2,
          pressure: 1,
          timeMs: i * 8,
        );
      }
      await Future<void>.delayed(hold * 3);
    }

    void lift(_P p) =>
        c.endStroke(pointer: 1, x: p.$1, y: p.$2, pressure: 1, timeMs: 9999);

    test('a held circle becomes a clean circle', () async {
      final path = _circle();
      await drawAndHold(path);
      expect(c.recognizedShape, ShapeKind.circle);
      lift(path.last);

      expect(c.strokes, hasLength(1));
      expect(c.strokes.single.points, hasLength(73));
    });

    test('an unrecognized stroke keeps the original points', () async {
      final path = [
        for (var i = 0; i < 40; i++) (100.0 + i * 3, 100 + _noise(i) * 30),
      ];
      await drawAndHold(path);
      expect(c.recognizedShape, isNull);
      lift(path.last);

      expect(c.strokes.single.points.length, greaterThan(20));
    });

    test('lifting before the hold time keeps the original stroke', () {
      final path = _circle();
      c.beginStroke(
        pointer: 1,
        x: path.first.$1,
        y: path.first.$2,
        pressure: 1,
        timeMs: 0,
      );
      for (var i = 1; i < path.length; i++) {
        c.extendStroke(
          pointer: 1,
          x: path[i].$1,
          y: path[i].$2,
          pressure: 1,
          timeMs: i * 8,
        );
      }
      lift(path.last);

      expect(c.strokes.single.points, hasLength(path.length));
    });

    test('the snapped result is one undo step', () async {
      final path = _circle();
      await drawAndHold(path);
      lift(path.last);
      c.undo();
      expect(c.strokes, isEmpty);
    });
  });
}
