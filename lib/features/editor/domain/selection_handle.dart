enum SelectionHandle {
  topLeft(-1, -1),
  top(0, -1),
  topRight(1, -1),
  right(1, 0),
  bottomRight(1, 1),
  bottom(0, 1),
  bottomLeft(-1, 1),
  left(-1, 0);

  const SelectionHandle(this.fx, this.fy);

  /// -1 = left side, 1 = right side, 0 = centre.
  final int fx;

  /// -1 = top side, 1 = bottom side, 0 = centre.
  final int fy;

  bool get isCorner => fx != 0 && fy != 0;
}

typedef HandleSpot = ({SelectionHandle handle, double x, double y});