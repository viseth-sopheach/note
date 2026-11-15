import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/ink_normalizer.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_grouper.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

Stroke _s(String id, List<(double, double)> pts, {bool timed = false}) =>
    Stroke(
      id: id,
      tool: StrokeTool.autoPen,
      colorValue: 0xFF000000,
      width: 2,
      points: [
        for (var i = 0; i < pts.length; i++)
          StrokePoint(
            x: pts[i].$1,
            y: pts[i].$2,
            timestampMs: timed ? i * 16 : 0,
          ),
      ],
    );

void main() {
  group('StrokeGrouper', () {
    test('strokes of one character stay together', () {
      final g = StrokeGrouper.group([
        _s('a', [(0, 0), (0, 40)]),
        _s('b', [(20, 20), (60, 20)]),
      ]);
      expect(g, hasLength(1));
    });

    test('far apart words are separate groups', () {
      final g = StrokeGrouper.group([
        _s('a', [(0, 0), (30, 40)]),
        _s('b', [(400, 0), (430, 40)]),
      ]);
      expect(g, hasLength(2));
    });

    test('a dot above a stem joins it', () {
      final g = StrokeGrouper.group([
        _s('stem', [(0, 20), (0, 60)]),
        _s('dot', [(0, 5), (1, 5)]),
      ]);
      expect(g, hasLength(1));
    });

    test('separate lines are not merged', () {
      final g = StrokeGrouper.group([
        _s('l1', [(0, 0), (100, 40)]),
        _s('l2', [(0, 100), (100, 140)]),
      ]);
      expect(g, hasLength(2));
    });
  });

  group('InkNormalizer', () {
    test('starts at the origin and timestamps strictly increase', () {
      final out = InkNormalizer.normalize([
        _s('a', [(500, 500), (540, 560), (560, 600)], timed: true),
        _s('b', [(580, 520), (600, 560)], timed: true),
      ]);
      final all = [for (final s in out) ...s];
      expect(all.map((p) => p.x).reduce((a, b) => a < b ? a : b), 0);
      expect(all.map((p) => p.y).reduce((a, b) => a < b ? a : b), 0);
      for (var i = 1; i < all.length; i++) {
        expect(all[i].t, greaterThan(all[i - 1].t));
      }
    });

    test('untimed strokes get synthetic timestamps', () {
      final out = InkNormalizer.normalize([
        _s('a', [(0, 0), (10, 10), (20, 20)]),
      ]);
      expect(out.single.map((p) => p.t).toSet(), hasLength(3));
    });
  });
}
