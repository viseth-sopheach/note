import 'stroke_selection.dart' show Bounds, Vertex;

/// Images and text boxes picked by the lasso.
final class ObjectSelection {
  const ObjectSelection({this.imageIds = const {}, this.textIds = const {}});

  static const ObjectSelection empty = ObjectSelection();

  final Set<String> imageIds;
  final Set<String> textIds;

  bool get isEmpty => imageIds.isEmpty && textIds.isEmpty;
}

/// What the drawing controller needs from the images and text boxes of a page.
abstract interface class PageObjects {
  ObjectSelection pickInside(List<Vertex> lasso);

  Bounds? boundsOf(ObjectSelection selection);

  void moveBy(ObjectSelection selection, double dx, double dy);

  void remove(ObjectSelection selection);
}
