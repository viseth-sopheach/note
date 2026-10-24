enum SelectionHandle {
  topLeft(-1, -1),
  top(0, -1),
  topRight(1, -1),
  right(1, 0),
  bottomRight(1, 1),
  bottom(0, 1),
  bottomLeft(-1, 1),
  left(-1, 0),
  start(0, 0),
  end(0, 0);

  const SelectionHandle(this.fx, this.fy);

  final int fx;
  final int fy;

  bool get isCorner => fx != 0 && fy != 0;
  bool get isEndpoint => this == start || this == end;
}

typedef HandleSpot = ({SelectionHandle handle, double x, double y});
