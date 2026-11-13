enum StrokeTool {
  pen,
  highlighter,
  eraser,
  select,
  line,
  rectangle,
  ellipse,
  triangle,
  arrow,
  // Appended: the index is stored in saved pages. Never reorder.
  physicalPen,
  autoPen;

  bool get isShape => switch (this) {
    StrokeTool.line ||
    StrokeTool.rectangle ||
    StrokeTool.ellipse ||
    StrokeTool.triangle ||
    StrokeTool.arrow => true,
    _ => false,
  };

  /// Pens drawn with pressure/speed width.
  bool get isNaturalPen =>
      this == StrokeTool.physicalPen || this == StrokeTool.autoPen;
}
