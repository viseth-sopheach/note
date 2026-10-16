enum StrokeTool {
  pen,
  highlighter,
  eraser,
  select,
  line,
  rectangle,
  ellipse,
  triangle;

  bool get isShape => index >= StrokeTool.line.index;
}