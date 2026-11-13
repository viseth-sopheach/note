import 'stroke_tool.dart';

/// Maps the 1-100% tip-size slider to a stroke width in document units.
abstract final class TipSize {
  static const int minPercent = 1;
  static const int maxPercent = 100;

  static const double penMin = 0.5;
  static const double penMax = 20;
  static const double highlighterMin = 1;
  static const double highlighterMax = 8;

  static (double, double) _range(StrokeTool tool) =>
      tool == StrokeTool.highlighter
      ? (highlighterMin, highlighterMax)
      : (penMin, penMax);

  static double widthFor(StrokeTool tool, int percent) {
    final (lo, hi) = _range(tool);
    final f =
        (percent.clamp(minPercent, maxPercent) - minPercent) /
        (maxPercent - minPercent);
    return lo + (hi - lo) * f;
  }

  static int percentFor(StrokeTool tool, double width) {
    final (lo, hi) = _range(tool);
    final f = ((width - lo) / (hi - lo)).clamp(0.0, 1.0);
    return (minPercent + f * (maxPercent - minPercent)).round();
  }
}
