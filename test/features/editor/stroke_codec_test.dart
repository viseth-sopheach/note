import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/shape_recognizer.dart';
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
    ShapeKind? shape,
  }) => Stroke(
    id: id,
    tool: tool,
    colorValue: color,
    width: width,
    shape: shape,
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

    expect(StrokeCodec.decode(StrokeCodec.encode(strokes)), strokes);
  });

  test('shapes survive a round trip and freehand stays null', () {
    final strokes = [
      stroke('l', shape: ShapeKind.line),
      stroke('r', shape: ShapeKind.rectangle),
      stroke('e', shape: ShapeKind.ellipse),
      stroke('t', shape: ShapeKind.triangle),
      stroke('f'),
    ];

    final decoded = StrokeCodec.decode(StrokeCodec.encode(strokes));

    expect(decoded, strokes);
    expect(decoded.last.shape, isNull);
  });

  test('version 1 data decodes with shape null', () {
    final bytes = Uint8List(36);
    final d = ByteData.sublistView(bytes);
    var o = 0;
    d.setUint8(o++, 1); // version
    d.setUint32(o, 1, Endian.little); // stroke count
    o += 4;
    d.setUint8(o++, 1); // id length
    d.setUint8(o++, 'a'.codeUnitAt(0));
    d.setUint8(o++, StrokeTool.pen.index);
    d.setUint32(o, 0xFF000000, Endian.little);
    o += 4;
    d.setFloat32(o, 2, Endian.little);
    o += 4;
    d.setUint32(o, 1, Endian.little); // point count
    o += 4;
    d.setFloat32(o, 5, Endian.little);
    o += 4;
    d.setFloat32(o, 6, Endian.little);
    o += 4;
    d.setFloat32(o, 1, Endian.little);
    o += 4;
    d.setUint32(o, 0, Endian.little);

    final decoded = StrokeCodec.decode(bytes);

    expect(decoded, hasLength(1));
    expect(decoded.single.id, 'a');
    expect(decoded.single.shape, isNull);
    expect(decoded.single.points.single.x, 5);
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
