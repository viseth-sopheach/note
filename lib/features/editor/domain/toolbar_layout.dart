import 'stroke_tool.dart';

abstract final class ToolbarLayout {
  /// Tools to show, in order. Duplicates are dropped, missing tools are
  /// appended, and the [active] tool is never hidden.
  static List<StrokeTool> visible({
    required List<StrokeTool> order,
    required Set<StrokeTool> hidden,
    required StrokeTool active,
  }) {
    final seen = <StrokeTool>{};
    final result = <StrokeTool>[];
    for (final tool in [...order, ...StrokeTool.values]) {
      if (!seen.add(tool)) continue;
      if (hidden.contains(tool) && tool != active) continue;
      result.add(tool);
    }
    return result;
  }
}
