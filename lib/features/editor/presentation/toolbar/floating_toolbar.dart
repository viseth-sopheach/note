import 'package:flutter/material.dart';

import '../../application/drawing_controller.dart';
import '../../application/measure_controller.dart';
import '../../domain/stroke_tool.dart';
import 'ink_palette.dart';

const List<double> _penWidths = [1, 2, 4, 6];
const List<double> _highlighterWidths = [2, 3, 4];

class FloatingToolbar extends StatefulWidget {
  const FloatingToolbar({
    super.key,
    required this.controller,
    required this.fingerDraws,
    required this.onFingerDrawsChanged,
    required this.onBack,
    required this.onPages,
    required this.onExport,
    required this.onImportPdf,
    required this.onAddPage,
    required this.onToggleMeasure,
    required this.onSettings,
    required this.onComingSoon,
    this.busy = false,
  });

  final DrawingController controller;
  final bool fingerDraws;
  final ValueChanged<bool> onFingerDrawsChanged;
  final VoidCallback onBack;
  final VoidCallback onPages;
  final VoidCallback onExport;
  final VoidCallback onImportPdf;
  final VoidCallback onAddPage;
  final void Function(MeasureKind kind) onToggleMeasure;
  final VoidCallback onSettings;
  final void Function(String label) onComingSoon;
  final bool busy;

  @override
  State<FloatingToolbar> createState() => _FloatingToolbarState();
}

class _FloatingToolbarState extends State<FloatingToolbar> {
  bool _expanded = false;

  DrawingController get _c => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          return Row(
            children: [
              _Pill(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: widget.onBack,
                  ),
                  IconButton(
                    tooltip: 'Pages',
                    icon: const Icon(Icons.grid_view_outlined),
                    onPressed: widget.onPages,
                  ),
                  IconButton(
                    tooltip: 'Undo (Ctrl+Z)',
                    icon: const Icon(Icons.undo),
                    onPressed: _c.canUndo ? _c.undo : null,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _Pill(children: _centerTools()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                children: [
                  IconButton(
                    tooltip: 'Export PDF (Ctrl+E)',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: widget.busy ? null : widget.onExport,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Insert',
                    icon: const Icon(Icons.add),
                    onSelected: (v) {
                      switch (v) {
                        case 'pdf':
                          widget.onImportPdf();
                        case 'page':
                          widget.onAddPage();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'pdf',
                        child: ListTile(
                          leading: Icon(Icons.upload_file),
                          title: Text('Import PDF from device'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'page',
                        child: ListTile(
                          leading: Icon(Icons.note_add_outlined),
                          title: Text('Add page'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: widget.fingerDraws
                        ? 'Finger draws (tap for stylus only)'
                        : 'Stylus only (tap to draw with finger)',
                    isSelected: !widget.fingerDraws,
                    icon: const Icon(Icons.touch_app_outlined),
                    selectedIcon: const Icon(Icons.do_not_touch_outlined),
                    onPressed: () =>
                        widget.onFingerDrawsChanged(!widget.fingerDraws),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (v) {
                      switch (v) {
                        case 'ruler':
                          widget.onToggleMeasure(MeasureKind.ruler);
                        case 'protractor':
                          widget.onToggleMeasure(MeasureKind.protractor);
                        case 'settings':
                          widget.onSettings();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'ruler', child: Text('Ruler')),
                      PopupMenuItem(
                        value: 'protractor',
                        child: Text('Protractor'),
                      ),
                      PopupMenuItem(value: 'settings', child: Text('Settings')),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _centerTools() {
    Widget tool(StrokeTool t, IconData icon, String tip) => _ToolButton(
      icon: icon,
      tooltip: tip,
      selected: _c.tool == t,
      onPressed: () => _c.selectTool(t),
    );

    return [
      _InkToolButton(
        controller: _c,
        tool: StrokeTool.pen,
        icon: Icons.edit_outlined,
        tooltip: 'Pen',
      ),
      _InkToolButton(
        controller: _c,
        tool: StrokeTool.highlighter,
        icon: Icons.highlight_outlined,
        tooltip: 'Highlighter',
      ),
      tool(StrokeTool.eraser, Icons.cleaning_services_outlined, 'Eraser'),
      tool(StrokeTool.select, Icons.gesture, 'Lasso select'),
      _ToolButton(
        icon: Icons.text_fields,
        tooltip: 'Text box',
        onPressed: () => widget.onComingSoon('Text box'),
      ),
      _ToolButton(
        icon: Icons.mic_none,
        tooltip: 'Audio / comment',
        onPressed: () => widget.onComingSoon('Audio'),
      ),
      IconButton(
        tooltip: 'AI assistant',
        icon: const Text('AI', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => widget.onComingSoon('AI assistant'),
      ),
      if (_expanded) ...[
        tool(StrokeTool.line, Icons.horizontal_rule, 'Line'),
        tool(StrokeTool.rectangle, Icons.rectangle_outlined, 'Rectangle'),
        tool(StrokeTool.ellipse, Icons.circle_outlined, 'Ellipse'),
        tool(StrokeTool.triangle, Icons.change_history_outlined, 'Triangle'),
      ],
      IconButton(
        tooltip: _expanded ? 'Fewer tools' : 'More tools',
        icon: Icon(_expanded ? Icons.chevron_left : Icons.chevron_right),
        onPressed: () => setState(() => _expanded = !_expanded),
      ),
    ];
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: dark
          ? theme.colorScheme.surfaceContainerHigh
          : const Color(0xFFEDEDF0),
      elevation: 4,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? colors.primary.withValues(alpha: 0.18)
            : null,
        foregroundColor: selected ? colors.primary : null,
      ),
      onPressed: onPressed,
    );
  }
}

/// Pen / highlighter button. Tap to select, tap again for color and size.
class _InkToolButton extends StatefulWidget {
  const _InkToolButton({
    required this.controller,
    required this.tool,
    required this.icon,
    required this.tooltip,
  });

  final DrawingController controller;
  final StrokeTool tool;
  final IconData icon;
  final String tooltip;

  @override
  State<_InkToolButton> createState() => _InkToolButtonState();
}

class _InkToolButtonState extends State<_InkToolButton> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final selected = c.tool == widget.tool;
    return MenuAnchor(
      controller: _menu,
      menuChildren: [_InkOptions(controller: c, tool: widget.tool)],
      child: _ToolButton(
        icon: widget.icon,
        tooltip: widget.tooltip,
        selected: selected,
        onPressed: () {
          if (!selected) {
            c.selectTool(widget.tool);
          } else {
            _menu.isOpen ? _menu.close() : _menu.open();
          }
        },
      ),
    );
  }
}

class _InkOptions extends StatelessWidget {
  const _InkOptions({required this.controller, required this.tool});

  final DrawingController controller;
  final StrokeTool tool;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final widths = tool == StrokeTool.pen ? _penWidths : _highlighterWidths;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final ink in kInkColors)
                  GestureDetector(
                    onTap: () => controller.selectColor(ink.value),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(ink.value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ink.value == controller.colorValue
                              ? colors.primary
                              : colors.outlineVariant,
                          width: ink.value == controller.colorValue ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final w in widths)
                  GestureDetector(
                    onTap: () => controller.selectWidth(w),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: w == controller.width
                            ? colors.secondaryContainer
                            : null,
                        border: Border.all(
                          color: w == controller.width
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                      child: Container(
                        width: 4 + w * 2,
                        height: 4 + w * 2,
                        decoration: BoxDecoration(
                          color: Color(controller.colorValue).withValues(
                            alpha: 1,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}