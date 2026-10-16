import 'package:flutter/material.dart';

import '../../application/drawing_controller.dart';
import '../../application/measure_controller.dart';
import '../../domain/stroke_tool.dart';

class _InkColor {
  const _InkColor(this.name, this.value);

  final String name;
  final int value;
}

const List<_InkColor> _palette = [
  _InkColor('Black', 0xFF1B1B1F),
  _InkColor('Blue', 0xFF1E5AA8),
  _InkColor('Red', 0xFFC62828),
  _InkColor('Green', 0xFF2E7D32),
  _InkColor('Orange', 0xFFEF6C00),
  _InkColor('Yellow', 0xFFFFEB3B),
];

const List<double> _penWidths = [1, 2, 4, 6];
const List<double> _highlighterWidths = [2, 3, 4];

const List<(StrokeTool, IconData, String)> _shapes = [
  (StrokeTool.line, Icons.horizontal_rule, 'Line (Shift: 15° steps)'),
  (StrokeTool.rectangle, Icons.crop_square, 'Rectangle (Shift: square)'),
  (StrokeTool.ellipse, Icons.circle_outlined, 'Ellipse (Shift: circle)'),
  (StrokeTool.triangle, Icons.change_history_outlined, 'Triangle'),
];

class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({
    super.key,
    required this.controller,
    this.fingerDraws = false,
    this.onFingerDrawsChanged,
    this.measure,
    this.onToggleMeasure,
  });

  final DrawingController controller;
  final bool fingerDraws;
  final ValueChanged<bool>? onFingerDrawsChanged;
  final MeasureController? measure;
  final ValueChanged<MeasureKind>? onToggleMeasure;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final m = measure;

    return Material(
      color: colors.surface,
      elevation: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Theme(
          data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
          child: ListenableBuilder(
            listenable: Listenable.merge([controller, if (m != null) m]),
            builder: (context, _) {
              final tool = controller.tool;
              final showInkOptions = tool == StrokeTool.pen ||
                  tool == StrokeTool.highlighter ||
                  tool.isShape;
              final widths =
                  tool == StrokeTool.highlighter ? _highlighterWidths : _penWidths;
              return Row(
                children: [
                  IconButton(
                    tooltip: 'Undo (Ctrl+Z)',
                    icon: const Icon(Icons.undo),
                    onPressed: controller.canUndo ? controller.undo : null,
                  ),
                  IconButton(
                    tooltip: 'Redo (Ctrl+Y)',
                    icon: const Icon(Icons.redo),
                    onPressed: controller.canRedo ? controller.redo : null,
                  ),
                  IconButton(
                    tooltip: 'Delete selection (Delete)',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: controller.hasSelection
                        ? controller.deleteSelection
                        : null,
                  ),
                  IconButton(
                    tooltip: fingerDraws
                        ? 'Finger draws (tap to use finger for pan/zoom)'
                        : 'Finger pans and zooms (tap to draw with finger)',
                    isSelected: fingerDraws,
                    icon: const Icon(Icons.touch_app_outlined),
                    selectedIcon: const Icon(Icons.touch_app),
                    onPressed: onFingerDrawsChanged == null
                        ? null
                        : () => onFingerDrawsChanged!(!fingerDraws),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<StrokeTool>(
                    showSelectedIcon: false,
                    emptySelectionAllowed: true,
                    segments: const [
                      ButtonSegment(
                        value: StrokeTool.pen,
                        icon: Icon(Icons.edit_outlined),
                        label: Text('Pen'),
                      ),
                      ButtonSegment(
                        value: StrokeTool.highlighter,
                        icon: Icon(Icons.highlight_outlined),
                        label: Text('Highlighter'),
                      ),
                      ButtonSegment(
                        value: StrokeTool.eraser,
                        icon: Icon(Icons.cleaning_services_outlined),
                        label: Text('Eraser'),
                      ),
                      ButtonSegment(
                        value: StrokeTool.select,
                        icon: Icon(Icons.gesture),
                        label: Text('Select'),
                      ),
                    ],
                    selected: tool.isShape ? <StrokeTool>{} : {tool},
                    onSelectionChanged: (s) {
                      if (s.isNotEmpty) controller.selectTool(s.first);
                    },
                  ),
                  const SizedBox(width: 4),
                  const SizedBox(height: 24, child: VerticalDivider(width: 16)),
                  for (final (t, icon, tip) in _shapes)
                    IconButton(
                      tooltip: tip,
                      isSelected: tool == t,
                      icon: Icon(icon),
                      style: tool == t
                          ? IconButton.styleFrom(
                              backgroundColor: colors.secondaryContainer,
                            )
                          : null,
                      onPressed: () => controller.selectTool(t),
                    ),
                  if (m != null && onToggleMeasure != null) ...[
                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(width: 16),
                    ),
                    IconButton(
                      tooltip: 'Ruler (R)',
                      isSelected: m.kind == MeasureKind.ruler,
                      icon: const Icon(Icons.straighten),
                      style: m.kind == MeasureKind.ruler
                          ? IconButton.styleFrom(
                              backgroundColor: colors.secondaryContainer,
                            )
                          : null,
                      onPressed: () => onToggleMeasure!(MeasureKind.ruler),
                    ),
                    IconButton(
                      tooltip: 'Protractor',
                      isSelected: m.kind == MeasureKind.protractor,
                      icon: const Icon(Icons.architecture),
                      style: m.kind == MeasureKind.protractor
                          ? IconButton.styleFrom(
                              backgroundColor: colors.secondaryContainer,
                            )
                          : null,
                      onPressed: () => onToggleMeasure!(MeasureKind.protractor),
                    ),
                  ],
                  if (showInkOptions) ...[
                    const SizedBox(width: 16),
                    for (final c in _palette)
                      _ColorSwatch(
                        color: c,
                        selected: c.value == controller.colorValue,
                        onTap: () => controller.selectColor(c.value),
                      ),
                    const SizedBox(width: 16),
                    for (final w in widths)
                      _WidthChip(
                        width: w,
                        selected: w == controller.width,
                        color: Color(controller.colorValue),
                        onTap: () => controller.selectWidth(w),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final _InkColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = Color(color.value);
    final onFill =
        ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: color.name,
        child: Semantics(
          button: true,
          selected: selected,
          label: '${color.name} ink',
          child: InkResponse(
            onTap: onTap,
            radius: 20,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: selected ? Icon(Icons.check, size: 16, color: onFill) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _WidthChip extends StatelessWidget {
  const _WidthChip({
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
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Width ${width.toStringAsFixed(0)}',
        child: Semantics(
          button: true,
          selected: selected,
          label: 'Stroke width ${width.toStringAsFixed(0)}',
          child: InkResponse(
            onTap: onTap,
            radius: 20,
            child: Container(
              width: 26,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? colors.secondaryContainer : null,
                border: Border.all(
                  color: selected ? colors.primary : colors.outlineVariant,
                ),
              ),
              child: Container(
                width: 4 + width * 2,
                height: 4 + width * 2,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 1),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outlineVariant),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}