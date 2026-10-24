import 'dart:convert';

/// One text box on a page. Coordinates are paper units (A4 at 96 dpi),
/// relative to the paper's top-left corner.
final class PageText {
  const PageText({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.colorValue,
    this.fontSize = 20,
    this.align = 0,
  });

  final String id;
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;
  final int colorValue;
  final double fontSize;

  /// 0 left, 1 center, 2 right.
  final int align;

  PageText copyWith({
    String? text,
    double? x,
    double? y,
    double? width,
    double? height,
    double? fontSize,
    int? colorValue,
    int? align,
  }) => PageText(
    id: id,
    text: text ?? this.text,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    colorValue: colorValue ?? this.colorValue,
    fontSize: fontSize ?? this.fontSize,
    align: align ?? this.align,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'text': text,
    'x': x,
    'y': y,
    'w': width,
    'h': height,
    'c': colorValue,
    's': fontSize,
    'a': align,
  };

  /// Returns null for malformed entries instead of throwing.
  static PageText? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final text = raw['text'];
    if (id is! String || text is! String) return null;

    double? number(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
    final x = number(raw['x']);
    final y = number(raw['y']);
    final w = number(raw['w']);
    final h = number(raw['h']);
    if (x == null || y == null || w == null || h == null) return null;
    if (w <= 0 || h <= 0) return null;
    final c = raw['c'];
    final s = number(raw['s']);
    final a = raw['a'];
    return PageText(
      id: id,
      text: text,
      x: x,
      y: y,
      width: w,
      height: h,
      colorValue: c is int ? c : 0xFF1B1B1F,
      fontSize: s != null && s > 0 ? s : 20,
      align: a is int && a >= 0 && a <= 2 ? a : 0,
    );
  }

  static String encodeList(List<PageText> texts) =>
      jsonEncode([for (final t in texts) t.toJson()]);

  static List<PageText> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return [for (final e in data) ?tryFromJson(e)];
    } on FormatException {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PageText &&
      other.id == id &&
      other.text == text &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height &&
      other.colorValue == colorValue &&
      other.fontSize == fontSize &&
      other.align == align;

  @override
  int get hashCode =>
      Object.hash(id, text, x, y, width, height, colorValue, fontSize, align);
}