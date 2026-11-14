import 'package:flutter/foundation.dart';

import '../domain/stroke_tool.dart';

/// Tool, color and width shared by every page of the open notebook.
/// Pen, Physical Pen and Auto Alphabet Pen share one color and width;
/// the highlighter keeps its own.
class ToolSettings extends ChangeNotifier {
  ToolSettings({
    StrokeTool tool = StrokeTool.pen,
    int penColorValue = 0xFF1B1B1F,
    int highlighterColorValue = 0xFFFFEB3B,
    double penWidth = 2,
    double highlighterWidth = 3,
    bool shapeRecognition = true,
    double eraserRadius = eraserDefault,
    double laserScale = laserDefault,
  }) : _tool = tool,
       _penColor = penColorValue,
       _highlighterColor = highlighterColorValue,
       // ignore: prefer_initializing_formals
       _penWidth = penWidth,
       // ignore: prefer_initializing_formals
       _highlighterWidth = highlighterWidth,
       // ignore: prefer_initializing_formals
       _shapeRecognition = shapeRecognition,
       _eraserRadius = eraserRadius,
       _laserScale = laserScale {
    _colorValue = tool == StrokeTool.highlighter
        ? _highlighterColor
        : _penColor;
    _width = tool == StrokeTool.highlighter ? _highlighterWidth : _penWidth;
  }

  static const double eraserMin = 4;
  static const double eraserMax = 48;
  static const double eraserDefault = 10;

  static const double laserMin = 0.4;
  static const double laserMax = 3.0;
  static const double laserDefault = 1.0;

  StrokeTool _tool;
  int _penColor;
  int _highlighterColor;
  double _penWidth;
  double _highlighterWidth;
  bool _shapeRecognition;
  double _eraserRadius;
  double _laserScale;
  late int _colorValue;
  late double _width;

  StrokeTool get tool => _tool;
  int get colorValue => _colorValue;
  double get width => _width;
  double get penWidth => _penWidth;
  double get highlighterWidth => _highlighterWidth;
  double get eraserRadius => _eraserRadius;
  double get laserScale => _laserScale;

  /// Hold at the end of a pen or highlighter stroke to snap it to a shape.
  bool get shapeRecognition => _shapeRecognition;

  bool get _usesPenSlot => _tool == StrokeTool.pen || _tool.isNaturalPen;

  void selectShapeRecognition(bool enabled) {
    if (enabled == _shapeRecognition) return;
    _shapeRecognition = enabled;
    notifyListeners();
  }

  void selectTool(StrokeTool tool) {
    if (tool == _tool) return;

    _tool = tool;

    switch (tool) {
      case StrokeTool.pen:
      case StrokeTool.physicalPen:
      case StrokeTool.autoPen:
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

    if (_usesPenSlot) _penColor = colorValue;
    if (_tool == StrokeTool.highlighter) _highlighterColor = colorValue;

    notifyListeners();
  }

  void selectWidth(double width) {
    if (width == _width) return;

    _width = width;

    if (_usesPenSlot) _penWidth = width;
    if (_tool == StrokeTool.highlighter) _highlighterWidth = width;

    notifyListeners();
  }

  void selectEraserRadius(double radius) {
    final v = radius.clamp(eraserMin, eraserMax).toDouble();
    if (v == _eraserRadius) return;
    _eraserRadius = v;
    notifyListeners();
  }

  void selectLaserScale(double v) {
    final s = v.clamp(laserMin, laserMax).toDouble();
    if (s == _laserScale) return;
    _laserScale = s;
    notifyListeners();
  }
}
