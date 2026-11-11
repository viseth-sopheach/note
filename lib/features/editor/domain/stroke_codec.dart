import 'dart:convert';
import 'dart:typed_data';

import 'shape_recognizer.dart' show ShapeKind;
import 'stroke.dart';
import 'stroke_point.dart';
import 'stroke_tool.dart';

/// Compact binary format for the strokes of one page. No Flutter imports.
///
/// Layout (little endian):
///   u8 version, u32 strokeCount, then per stroke:
///   u8 idLength, id (utf8), u8 tool index,
///   [v2+] u8 shape (0 line, 1 rectangle, 2 ellipse, 3 triangle,
///     4 arrow, 255 none),
///   [v3] u8 flags (bit 0 = filled),
///   [v4] u32 fill color (0 = none) after the shape byte,
///   u32 color, f32 width, u32 pointCount,
///   then per point: f32 x, f32 y, f32 pressure, u32 timeMs.
///
/// Never reorder StrokeTool values: the index is stored. Only append.
abstract final class StrokeCodec {
  static const int formatVersion = 4;
  static const int _pointSize = 16;
  static const int _noShape = 255;

  static int _shapeByte(ShapeKind? s) => switch (s) {
    ShapeKind.line => 0,
    ShapeKind.rectangle || ShapeKind.square => 1,
    ShapeKind.ellipse || ShapeKind.circle => 2,
    ShapeKind.triangle => 3,
    ShapeKind.arrow => 4,
    _ => _noShape,
  };

  static ShapeKind? _shapeFrom(int b) => switch (b) {
    0 => ShapeKind.line,
    1 => ShapeKind.rectangle,
    2 => ShapeKind.ellipse,
    3 => ShapeKind.triangle,
    4 => ShapeKind.arrow,
    _ => null,
  };

  static Uint8List encode(List<Stroke> strokes) {
    final ids = [for (final s in strokes) utf8.encode(s.id)];

    var size = 1 + 4;
    for (var i = 0; i < strokes.length; i++) {
      if (ids[i].length > 255) {
        throw ArgumentError.value(strokes[i].id, 'id', 'Id is too long');
      }
      size += 1 + ids[i].length + 1 + 4 + 4 + 4 + 4 + 4;
      size += strokes[i].points.length * _pointSize;
    }

    final bytes = Uint8List(size);
    final data = ByteData.sublistView(bytes);
    var o = 0;

    data.setUint8(o, formatVersion);
    o += 1;
    data.setUint32(o, strokes.length, Endian.little);
    o += 4;

    for (var i = 0; i < strokes.length; i++) {
      final s = strokes[i];
      final id = ids[i];

      data.setUint8(o, id.length);
      o += 1;
      bytes.setRange(o, o + id.length, id);
      o += id.length;
      data.setUint8(o, s.tool.index);
      o += 1;
      data.setUint8(o, _shapeByte(s.shape));
      o += 1;
      data.setUint32(o, (s.fillColorValue ?? 0) & 0xFFFFFFFF, Endian.little);
      o += 4;
      data.setUint32(o, s.colorValue & 0xFFFFFFFF, Endian.little);
      o += 4;
      data.setFloat32(o, s.width, Endian.little);
      o += 4;
      data.setUint32(o, s.points.length, Endian.little);
      o += 4;

      for (final p in s.points) {
        data.setFloat32(o, p.x, Endian.little);
        o += 4;
        data.setFloat32(o, p.y, Endian.little);
        o += 4;
        data.setFloat32(o, p.pressure, Endian.little);
        o += 4;
        data.setUint32(o, p.timestampMs.clamp(0, 0xFFFFFFFF), Endian.little);
        o += 4;
      }
    }
    return bytes;
  }

  /// Throws [FormatException] when [bytes] are corrupt or unsupported.
  static List<Stroke> decode(Uint8List bytes) {
    try {
      return _decode(bytes);
    } on RangeError {
      throw const FormatException('Stroke data is truncated.');
    }
  }

  static List<Stroke> _decode(Uint8List bytes) {
    if (bytes.isEmpty) throw const FormatException('Stroke data is empty.');

    final data = ByteData.sublistView(bytes);
    var o = 0;

    final version = data.getUint8(o);
    o += 1;
    if (version < 1 || version > 4) {
      throw FormatException('Unsupported stroke format: $version');
    }

    final count = data.getUint32(o, Endian.little);
    o += 4;

    final strokes = <Stroke>[];
    for (var i = 0; i < count; i++) {
      final idLength = data.getUint8(o);
      o += 1;
      if (o + idLength > bytes.length) {
        throw const FormatException('Stroke data is truncated.');
      }
      final id = utf8.decode(bytes.sublist(o, o + idLength));
      o += idLength;

      final toolIndex = data.getUint8(o);
      o += 1;
      if (toolIndex >= StrokeTool.values.length) {
        throw FormatException('Unknown tool: $toolIndex');
      }

      ShapeKind? shape;
      if (version >= 2) {
        shape = _shapeFrom(data.getUint8(o));
        o += 1;
      }

      int? fillColor;
      var legacyFilled = false;
      if (version == 3) {
        legacyFilled = (data.getUint8(o) & 1) != 0;
        o += 1;
      } else if (version >= 4) {
        final raw = data.getUint32(o, Endian.little);
        o += 4;
        fillColor = raw == 0 ? null : raw;
      }

      final color = data.getUint32(o, Endian.little);
      o += 4;
      if (legacyFilled) fillColor = color;
      final width = data.getFloat32(o, Endian.little);
      o += 4;
      final pointCount = data.getUint32(o, Endian.little);
      o += 4;

      if (pointCount * _pointSize > bytes.length - o) {
        throw const FormatException('Stroke data is truncated.');
      }

      final points = <StrokePoint>[];
      for (var j = 0; j < pointCount; j++) {
        final x = data.getFloat32(o, Endian.little);
        o += 4;
        final y = data.getFloat32(o, Endian.little);
        o += 4;
        final pressure = data.getFloat32(o, Endian.little);
        o += 4;
        final t = data.getUint32(o, Endian.little);
        o += 4;
        points.add(StrokePoint(x: x, y: y, pressure: pressure, timestampMs: t));
      }

      strokes.add(
        Stroke(
          id: id,
          tool: StrokeTool.values[toolIndex],
          colorValue: color,
          width: width,
          points: points,
          shape: shape,
          fillColorValue: fillColor,
        ),
      );
    }
    return strokes;
  }
}
