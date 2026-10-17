import '../../editor/domain/stroke_tool.dart';
import '../../library/domain/paper_template.dart';
import 'app_theme_mode.dart';
import 'layout_density.dart';

/// Every user preference. Immutable. Use [normalized] after loading.
final class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.accentColorValue = 0xFF607D8B,
    this.density = LayoutDensity.comfortable,
    this.showCovers = true,
    this.defaultTemplate = PaperTemplate.blank,
    this.defaultTool = StrokeTool.pen,
    this.penColorValue = 0xFF1B1B1F,
    this.penWidth = 2,
    this.highlighterColorValue = 0xFFFFEB3B,
    this.highlighterWidth = 3,
    this.defaultZoom = 1.0,
    this.wheelZoom = true,
    this.toolbarOrder = StrokeTool.values,
    this.hiddenTools = const {},
    this.undoLimit = 200,
    this.confirmDeletePage = true,
    this.rememberPosition = true,
    this.shapeRecognition = true,
  });

  static const List<double> penWidths = [1, 2, 4, 6];
  static const List<double> highlighterWidths = [2, 3, 4];
  static const List<double> zoomLevels = [0.5, 0.75, 1.0, 1.25, 1.5];
  static const List<int> undoLimits = [50, 100, 200, 500];

  final AppThemeMode themeMode;
  final int accentColorValue;
  final LayoutDensity density;
  final bool showCovers;

  final PaperTemplate defaultTemplate;

  /// Only [StrokeTool.pen] or [StrokeTool.highlighter].
  final StrokeTool defaultTool;
  final int penColorValue;
  final double penWidth;
  final int highlighterColorValue;
  final double highlighterWidth;

  /// Upper limit for the zoom used when a notebook opens. Narrow screens
  /// still fit the page width.
  final double defaultZoom;
  final bool wheelZoom;
  final List<StrokeTool> toolbarOrder;
  final Set<StrokeTool> hiddenTools;
  final int undoLimit;
  final bool confirmDeletePage;
  final bool rememberPosition;
  final bool shapeRecognition;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    int? accentColorValue,
    LayoutDensity? density,
    bool? showCovers,
    PaperTemplate? defaultTemplate,
    StrokeTool? defaultTool,
    int? penColorValue,
    double? penWidth,
    int? highlighterColorValue,
    double? highlighterWidth,
    double? defaultZoom,
    bool? wheelZoom,
    List<StrokeTool>? toolbarOrder,
    Set<StrokeTool>? hiddenTools,
    int? undoLimit,
    bool? confirmDeletePage,
    bool? rememberPosition,
    bool? shapeRecognition,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    accentColorValue: accentColorValue ?? this.accentColorValue,
    density: density ?? this.density,
    showCovers: showCovers ?? this.showCovers,
    defaultTemplate: defaultTemplate ?? this.defaultTemplate,
    defaultTool: defaultTool ?? this.defaultTool,
    penColorValue: penColorValue ?? this.penColorValue,
    penWidth: penWidth ?? this.penWidth,
    highlighterColorValue: highlighterColorValue ?? this.highlighterColorValue,
    highlighterWidth: highlighterWidth ?? this.highlighterWidth,
    defaultZoom: defaultZoom ?? this.defaultZoom,
    wheelZoom: wheelZoom ?? this.wheelZoom,
    toolbarOrder: toolbarOrder ?? this.toolbarOrder,
    hiddenTools: hiddenTools ?? this.hiddenTools,
    undoLimit: undoLimit ?? this.undoLimit,
    confirmDeletePage: confirmDeletePage ?? this.confirmDeletePage,
    rememberPosition: rememberPosition ?? this.rememberPosition,
    shapeRecognition: shapeRecognition ?? this.shapeRecognition,
  );

  /// Returns a copy with every value forced into its supported range:
  /// discrete lists, a full duplicate-free toolbar order, and at least one
  /// visible tool.
  AppSettings normalized() {
    final order = <StrokeTool>[];
    for (final tool in [...toolbarOrder, ...StrokeTool.values]) {
      if (!order.contains(tool)) order.add(tool);
    }
    var hidden = hiddenTools.where(order.contains).toSet();
    if (hidden.length >= order.length) hidden = <StrokeTool>{};

    return copyWith(
      defaultTool: defaultTool == StrokeTool.highlighter
          ? StrokeTool.highlighter
          : StrokeTool.pen,
      penWidth: penWidths.contains(penWidth) ? penWidth : 2,
      highlighterWidth: highlighterWidths.contains(highlighterWidth)
          ? highlighterWidth
          : 3,
      defaultZoom: zoomLevels.contains(defaultZoom) ? defaultZoom : 1.0,
      undoLimit: undoLimits.contains(undoLimit) ? undoLimit : 200,
      toolbarOrder: List<StrokeTool>.unmodifiable(order),
      hiddenTools: Set<StrokeTool>.unmodifiable(hidden),
    );
  }
}