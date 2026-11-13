import 'dart:math' as math;
import 'dart:ui' show Rect;

import '../domain/object_selection.dart';
import '../domain/stroke_selection.dart';
import 'page_images_controller.dart';
import 'page_texts_controller.dart';

class PageObjectsAdapter implements PageObjects {
  PageObjectsAdapter({required this.images, required this.texts});

  final PageImagesController images;
  final PageTextsController texts;

  static const int _grid = 6;
  static const double _minInside = 0.6;

  @override
  ObjectSelection pickInside(List<Vertex> lasso) => ObjectSelection(
    imageIds: {
      for (final i in images.images)
        if (_mostlyInside(lasso, Rect.fromLTWH(i.x, i.y, i.width, i.height)))
          i.id,
    },
    textIds: {
      for (final t in texts.texts)
        if (_mostlyInside(lasso, Rect.fromLTWH(t.x, t.y, t.width, t.height)))
          t.id,
    },
  );

  bool _mostlyInside(List<Vertex> lasso, Rect r) {
    var inside = 0;
    for (var iy = 0; iy < _grid; iy++) {
      for (var ix = 0; ix < _grid; ix++) {
        final x = r.left + r.width * (ix + 0.5) / _grid;
        final y = r.top + r.height * (iy + 0.5) / _grid;
        if (StrokeSelection.contains(lasso, x, y)) inside++;
      }
    }
    return inside >= _grid * _grid * _minInside;
  }

  @override
  Bounds? boundsOf(ObjectSelection s) {
    final rects = <Rect>[
      for (final i in images.images)
        if (s.imageIds.contains(i.id))
          Rect.fromLTWH(i.x, i.y, i.width, i.height),
      for (final t in texts.texts)
        if (s.textIds.contains(t.id))
          Rect.fromLTWH(t.x, t.y, t.width, t.height),
    ];
    if (rects.isEmpty) return null;
    var l = rects.first.left, t = rects.first.top;
    var r = rects.first.right, b = rects.first.bottom;
    for (final q in rects) {
      l = math.min(l, q.left);
      t = math.min(t, q.top);
      r = math.max(r, q.right);
      b = math.max(b, q.bottom);
    }
    return (left: l, top: t, right: r, bottom: b);
  }

  @override
  void moveBy(ObjectSelection s, double dx, double dy) {
    for (final id in s.imageIds) {
      images.moveBy(id, dx, dy);
    }
    for (final id in s.textIds) {
      texts.moveBy(id, dx, dy);
    }
  }

  @override
  void remove(ObjectSelection s) {
    for (final id in s.imageIds) {
      images.removeById(id);
    }
    for (final id in s.textIds) {
      texts.removeById(id);
    }
  }
}
