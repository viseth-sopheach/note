import 'package:flutter/foundation.dart';

import '../domain/stroke_tool.dart';

/// Tool, color and width shared by every page of the open notebook.
class ToolSettings extends ChangeNotifier {
  StrokeTool _tool = StrokeTool.pen;
  int _colorValue = 0xFF1B1B1F;
  double _width = 2;

  StrokeTool get tool => _tool;
  int get colorValue => _colorValue;
  double get width => _width;

  void selectTool(StrokeTool tool) {
    if (tool == _tool) return;
    _tool = tool;
    _width = tool == StrokeTool.highlighter ? 3 : 2;
    notifyListeners();
  }

  void selectColor(int colorValue) {
    if (colorValue == _colorValue) return;
    _colorValue = colorValue;
    notifyListeners();
  }

  void selectWidth(double width) {
    if (width == _width) return;
    _width = width;
    notifyListeners();
  }
}