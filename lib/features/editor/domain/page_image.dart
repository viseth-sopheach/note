import 'dart:convert';

/// One image placed on a page. Coordinates are in paper units (A4 at 96 dpi),
/// relative to the paper's top-left corner.
final class PageImage {
  const PageImage({
    required this.id,
    required this.path,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String id;

  /// Absolute path of the stored image file.
  final String path;
  final double x;
  final double y;
  final double width;
  final double height;

  double get aspect => width / height;

  PageImage copyWith({double? x, double? y, double? width, double? height}) =>
      PageImage(
        id: id,
        path: path,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  Map<String, Object> toJson() => {
    'id': id,
    'path': path,
    'x': x,
    'y': y,
    'w': width,
    'h': height,
  };

  /// Returns null for malformed entries instead of throwing.
  static PageImage? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final path = raw['path'];
    if (id is! String || path is! String) return null;

    double? number(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
    final x = number(raw['x']);
    final y = number(raw['y']);
    final w = number(raw['w']);
    final h = number(raw['h']);
    if (x == null || y == null || w == null || h == null) return null;
    if (w <= 0 || h <= 0) return null;
    return PageImage(id: id, path: path, x: x, y: y, width: w, height: h);
  }

  static String encodeList(List<PageImage> images) =>
      jsonEncode([for (final i in images) i.toJson()]);

  static List<PageImage> decodeList(String? raw) {
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
      other is PageImage &&
      other.id == id &&
      other.path == path &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(id, path, x, y, width, height);
}