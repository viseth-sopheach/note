import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_codec.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  Stroke stroke(
    String id, {
    StrokeTool tool = StrokeTool.pen,
    int color = 0xFFC62828,
    double width = 2,
  }) => Stroke(
    id: id,
    tool: tool,
    colorValue: color,
    width: width,
    points: const [
      StrokePoint(x: 1.5, y: 2.25, pressure: 0.5, timestampMs: 0),
      StrokePoint(x: 100, y: 200.5, pressure: 1, timestampMs: 16),
    ],
  );

  test('strokes survive a round trip', () {
    final strokes = [
      stroke('a'),
      stroke('b', tool: StrokeTool.highlighter, color: 0x59FFEB3B, width: 3),
    ];

    final decoded = StrokeCodec.decode(StrokeCodec.encode(strokes));

    expect(decoded, strokes);
  });

  test('an empty page round trips', () {
    expect(StrokeCodec.decode(StrokeCodec.encode(const [])), isEmpty);
  });

  test('a one-point stroke round trips', () {
    final dot = Stroke(
      id: 'dot',
      tool: StrokeTool.pen,
      colorValue: 0xFF000000,
      width: 2,
      points: const [StrokePoint(x: 5, y: 5)],
    );
    expect(StrokeCodec.decode(StrokeCodec.encode([dot])), [dot]);
  });

  test('truncated data throws FormatException', () {
    final bytes = StrokeCodec.encode([stroke('a')]);
    final cut = Uint8List.sublistView(bytes, 0, bytes.length - 3);
    expect(() => StrokeCodec.decode(cut), throwsFormatException);
  });

  test('unknown version and empty data throw FormatException', () {
    expect(
      () => StrokeCodec.decode(Uint8List.fromList([9, 0, 0, 0, 0])),
      throwsFormatException,
    );
    expect(() => StrokeCodec.decode(Uint8List(0)), throwsFormatException);
  });
}
