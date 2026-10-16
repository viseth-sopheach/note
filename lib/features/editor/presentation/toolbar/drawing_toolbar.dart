import 'package:flutter/material.dart';

import '../../application/drawing_controller.dart';
import '../../application/measure_controller.dart';
import '../../domain/stroke_tool.dart';
import '../../domain/toolbar_layout.dart';
import 'ink_palette.dart';

const List<double> _penWidths = [1, 2, 4, 6];
const List<double> _highlighterWidths = [2, 3, 4];
const Color _accent = Color(0xFF1E88E5);

class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({
    super.key,
    required this.controller,
    this.fingerDraws = false,
    this.onFingerDrawsChanged,
    this.toolOrder = StrokeTool.values,
    this.hiddenTools = const {},
    this.measure,
    this.onToggleMeasure,
    this.onBack,
    this.onAddPage,
    this.onExport,
  });

  final DrawingController controller;
  final bool fingerDraws;
  final ValueChanged<bool>? onFingerDrawsChanged;
  final List<StrokeTool> toolOrder;
  final Set<StrokeTool> hiddenTools;
  final MeasureController? measure;
  final void Function(MeasureKind kind)? onToggleMeasure;
  final VoidCallback? onBack;
  final VoidCallback? onAddPage;
  final VoidCallback? onExport;

  static IconData _icon(StrokeTool t) => switch (t) {
    StrokeTool.pen => Icons.edit_outlined,
    StrokeTool.highlighter => Icons.highlight_outlined,
    StrokeTool.eraser => Icons.cleaning_services_outlined,
    StrokeTool.select => Icons.gesture,
    StrokeTool.line => Icons.horizontal_rule,
    StrokeTool.rectangle => Icons.rectangle_outlined,
    StrokeTool.ellipse => Icons.circle_outlined,
    StrokeTool.triangle => Icons.change_history_outlined,
  };

  static String _label(StrokeTool t) => switch (t) {
    StrokeTool.pen => 'Pen',
    StrokeTool.highlighter => 'Highlighter',
    StrokeTool.eraser => 'Eraser',
    StrokeTool.select => 'Select',
    StrokeTool.line => 'Line',
    StrokeTool.rectangle => 'Rectangle',
    StrokeTool.ellipse => 'Ellipse',
    StrokeTool.triangle => 'Triangle',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final group = colors.surfaceContainerHighest.withValues(alpha: 0.6);

    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?measure]),
      builder: (context, _) {
        final tool = controller.tool;
        final showInk =
            tool == StrokeTool.pen || tool == StrokeTool.highlighter;
        final widths = tool == StrokeTool.pen ? _penWidths : _highlighterWidths;
        final visible = ToolbarLayout.visible(
          order: toolOrder,
          hidden: hiddenTools,
          active: tool,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: IconTheme(
                        data: const IconThemeData(
                          color: Color(0xFF222222),
                          size: 22,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onBack != null)
                              _btn(Icons.arrow_back, 'Back', onBack),
                            _btn(
                              Icons.undo,
                              'Undo (Ctrl+Z)',
                              controller.canUndo ? controller.undo : null,
                            ),
                            _btn(
                              Icons.redo,
                              'Redo (Ctrl+Y)',
                              controller.canRedo ? controller.redo : null,
                            ),
                            _gap(),
                            Container(
                              decoration: BoxDecoration(
                                color: group,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final t in visible)
                                    _btn(
                                      _icon(t),
                                      _label(t),
                                      () => controller.selectTool(t),
                                      selected: t == tool,
                                    ),
                                ],
                              ),
                            ),
                            _gap(),
                            _btn(
                              Icons.delete_outline,
                              'Delete selection (Delete)',
                              controller.hasSelection
                                  ? controller.deleteSelection
                                  : null,
                            ),
                            _btn(
                              Icons.touch_app_outlined,
                              fingerDraws
                                  ? 'Finger draws (tap for pan/zoom)'
                                  : 'Finger pans/zooms (tap to draw)',
                              onFingerDrawsChanged == null
                                  ? null
                                  : () => onFingerDrawsChanged!(!fingerDraws),
                              selected: fingerDraws,
                            ),
                            if (onAddPage != null)
                              _btn(Icons.add, 'Add page…', onAddPage),
                            if (onToggleMeasure != null || onExport != null)
                              PopupMenuButton<String>(
                                tooltip: 'More',
                                icon: const Icon(Icons.more_horiz),
                                onSelected: (v) {
                                  switch (v) {
                                    case 'ruler':
                                      onToggleMeasure?.call(MeasureKind.ruler);
                                    case 'protractor':
                                      onToggleMeasure?.call(
                                        MeasureKind.protractor,
                                      );
                                    case 'export':
                                      onExport?.call();
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (onToggleMeasure != null) ...const [
                                    PopupMenuItem(
                                      value: 'ruler',
                                      child: Text('Ruler (R)'),
                                    ),
                                    PopupMenuItem(
                                      value: 'protractor',
                                      child: Text('Protractor'),
                                    ),
                                  ],
                                  if (onExport != null)
                                    const PopupMenuItem(
                                      value: 'export',
                                      child: Text('Export PDF (Ctrl+E)'),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showInk)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final c in kInkColors)
                              _Swatch(
                                color: c,
                                selected: c.value == controller.colorValue,
                                onTap: () => controller.selectColor(c.value),
                              ),
                            const SizedBox(width: 12),
                            for (final w in widths)
                              _Width(
                                width: w,
                                selected: w == controller.width,
                                color: Color(controller.colorValue),
                                onTap: () => controller.selectWidth(w),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static Widget _gap() => const SizedBox(width: 6);

  static Widget _btn(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    bool selected = false,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      backgroundColor: selected
          ? _accent.withValues(alpha: 0.14)
          : Colors.transparent,
      foregroundColor: selected ? _accent : const Color(0xFF222222),
      disabledForegroundColor: Colors.black26,
    ),
    icon: Icon(icon),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final InkColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = Color(color.value);
    final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: color.name,
        child: InkResponse(
          onTap: onTap,
          radius: 20,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _accent : Colors.black12,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected ? Icon(Icons.check, size: 16, color: onFill) : null,
          ),
        ),
      ),
    );
  }
}

class _Width extends StatelessWidget {
  const _Width({
    required this.width,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Width ${width.toStringAsFixed(0)}',
        child: InkResponse(
          onTap: onTap,
          radius: 20,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? _accent.withValues(alpha: 0.14) : null,
            ),
            child: Container(
              width: 4 + width * 2,
              height: 4 + width * 2,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
