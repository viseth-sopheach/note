enum StrokeTool {
  pen,
  highlighter,
  eraser,
  select,
  line,
  rectangle,
  ellipse,
  triangle,
  arrow;

  bool get isShape => index >= StrokeTool.line.index;
}
