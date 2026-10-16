import 'package:flutter/foundation.dart';

import '../domain/stroke_tool.dart';

/// Tool, color and width shared by every page of the open notebook.
/// Pen and highlighter each remember their own color and width.
class ToolSettings extends ChangeNotifier {
  ToolSettings({
    StrokeTool tool = StrokeTool.pen,
    int penColorValue = 0xFF1B1B1F,
    int highlighterColorValue = 0xFFFFEB3B,
    double penWidth = 2,
    double highlighterWidth = 3,
  }) : _tool = tool,
       _penColor = penColorValue,
       _highlighterColor = highlighterColorValue,
       // Keep the public constructor parameter names compatible.
       // ignore: prefer_initializing_formals
       _penWidth = penWidth,
       // ignore: prefer_initializing_formals
       _highlighterWidth = highlighterWidth {
    _colorValue = tool == StrokeTool.highlighter
        ? _highlighterColor
        : _penColor;
    _width = tool == StrokeTool.highlighter ? _highlighterWidth : _penWidth;
  }

  StrokeTool _tool;
  int _penColor;
  int _highlighterColor;
  double _penWidth;
  double _highlighterWidth;
  late int _colorValue;
  late double _width;

  StrokeTool get tool => _tool;
  int get colorValue => _colorValue;
  double get width => _width;

  void selectTool(StrokeTool tool) {
    if (tool == _tool) return;

    _tool = tool;

    switch (tool) {
      case StrokeTool.pen:
        _colorValue = _penColor;
        _width = _penWidth;
      case StrokeTool.highlighter:
        _colorValue = _highlighterColor;
        _width = _highlighterWidth;
      default:
        break;
    }

    notifyListeners();
  }

  void selectColor(int colorValue) {
    if (colorValue == _colorValue) return;

    _colorValue = colorValue;

    if (_tool == StrokeTool.pen) _penColor = colorValue;
    if (_tool == StrokeTool.highlighter) {
      _highlighterColor = colorValue;
    }

    notifyListeners();
  }

  void selectWidth(double width) {
    if (width == _width) return;

    _width = width;

    if (_tool == StrokeTool.pen) _penWidth = width;
    if (_tool == StrokeTool.highlighter) {
      _highlighterWidth = width;
    }

    notifyListeners();
  }
}
