import 'package:flutter/material.dart';

import '../../../../app/glass/glass_icon_button.dart';
import '../../../../app/glass/glass_menu.dart';
import '../../../../app/glass/glass_pill.dart';
import '../../../../app/glass/glass_surface.dart';
import '../../../../app/glass/glass_theme.dart';
import '../../../../app/glass/glass_tokens.dart';
import '../../application/drawing_controller.dart';
import '../../application/measure_controller.dart';
import '../../domain/stroke_tool.dart';
import 'ink_palette.dart';

const List<double> _penWidths = [1, 2, 4, 6];
const List<double> _highlighterWidths = [2, 3, 4];
const double _menuWidth = 248;

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
    required this.onInsertImage,
    required this.onAddPage,
    required this.onToggleMeasure,
    required this.onSettings,
    required this.onComingSoon,
    required this.onDuplicatePage,
    required this.onDeletePage,
    this.busy = false,
  });

  final DrawingController controller;
  final bool fingerDraws;
  final ValueChanged<bool> onFingerDrawsChanged;
  final VoidCallback onBack;
  final VoidCallback onPages;
  final VoidCallback onExport;
  final VoidCallback onImportPdf;
  final VoidCallback onInsertImage;
  final VoidCallback onAddPage;
  final void Function(MeasureKind kind) onToggleMeasure;
  final VoidCallback onSettings;
  final void Function(String label) onComingSoon;
  final VoidCallback onDuplicatePage;

  /// Null hides the delete item (only one page left).
  final VoidCallback? onDeletePage;
  final bool busy;

  @override
  State<FloatingToolbar> createState() => _FloatingToolbarState();
}

class _FloatingToolbarState extends State<FloatingToolbar> {
  bool _expanded = false;

  DrawingController get _c => widget.controller;

  Future<T?> _menuBelow<T>(BuildContext anchor, List<GlassMenuItem<T>> items) {
    final box = anchor.findRenderObject()! as RenderBox;
    final corner = box.localToGlobal(Offset(box.size.width, box.size.height));
    return showGlassMenu<T>(
      context: anchor,
      position: Offset(corner.dx - _menuWidth, corner.dy + 6),
      items: items,
    );
  }

  Future<void> _showInsert(BuildContext anchor) async {
    final v = await _menuBelow<String>(anchor, const [
      GlassMenuItem(
        value: 'pdf',
        icon: Icons.upload_file,
        label: 'Import PDF from device',
      ),
      GlassMenuItem(
        value: 'image',
        icon: Icons.image_outlined,
        label: 'Insert image',
      ),
      GlassMenuItem(
        value: 'page',
        icon: Icons.note_add_outlined,
        label: 'Add page',
      ),
    ]);
    switch (v) {
      case 'pdf':
        widget.onImportPdf();
      case 'image':
        widget.onInsertImage();
      case 'page':
        widget.onAddPage();
    }
  }

  Future<void> _showMore(BuildContext anchor) async {
    final v = await _menuBelow<String>(anchor, [
      const GlassMenuItem(
        value: 'ruler',
        icon: Icons.straighten,
        label: 'Ruler',
      ),
      const GlassMenuItem(
        value: 'protractor',
        icon: Icons.architecture,
        label: 'Protractor',
      ),
      if (!widget.busy)
        const GlassMenuItem(
          value: 'duplicate',
          icon: Icons.file_copy_outlined,
          label: 'Duplicate page',
        ),
      if (!widget.busy && widget.onDeletePage != null)
        const GlassMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete page',
          destructive: true,
        ),
      const GlassMenuItem(
        value: 'settings',
        icon: Icons.settings_outlined,
        label: 'Settings',
      ),
    ]);
    switch (v) {
      case 'ruler':
        widget.onToggleMeasure(MeasureKind.ruler);
      case 'protractor':
        widget.onToggleMeasure(MeasureKind.protractor);
      case 'duplicate':
        widget.onDuplicatePage();
      case 'delete':
        widget.onDeletePage?.call();
      case 'settings':
        widget.onSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          return Row(
            children: [
              GlassPill(
                children: [
                  GlassIconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: widget.onBack,
                  ),
                  GlassIconButton(
                    tooltip: 'Pages',
                    icon: const Icon(Icons.grid_view_outlined),
                    onPressed: widget.onPages,
                  ),
                  GlassIconButton(
                    tooltip: 'Undo (Ctrl+Z)',
                    icon: const Icon(Icons.undo),
                    onPressed: _c.canUndo ? _c.undo : null,
                  ),
                  GlassIconButton(
                    tooltip: 'Redo (Ctrl+Y)',
                    icon: const Icon(Icons.redo),
                    onPressed: _c.canRedo ? _c.redo : null,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GlassPill(children: _centerTools()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassPill(
                children: [
                  GlassIconButton(
                    tooltip: 'Export PDF (Ctrl+E)',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: widget.busy ? null : widget.onExport,
                  ),
                  Builder(
                    builder: (ctx) => GlassIconButton(
                      tooltip: 'Insert',
                      icon: const Icon(Icons.add),
                      onPressed: () => _showInsert(ctx),
                    ),
                  ),
                  GlassIconButton(
                    tooltip: widget.fingerDraws
                        ? 'Finger draws (tap for stylus only)'
                        : 'Stylus only (tap to draw with finger)',
                    selected: !widget.fingerDraws,
                    icon: Icon(
                      widget.fingerDraws
                          ? Icons.touch_app_outlined
                          : Icons.do_not_touch_outlined,
                    ),
                    onPressed: () =>
                        widget.onFingerDrawsChanged(!widget.fingerDraws),
                  ),
                  Builder(
                    builder: (ctx) => GlassIconButton(
                      tooltip: 'More',
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () => _showMore(ctx),
                    ),
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
    Widget tool(StrokeTool t, IconData icon, String tip) => GlassIconButton(
      tooltip: tip,
      icon: Icon(icon),
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
      GlassIconButton(
        tooltip: 'Text box',
        icon: const Icon(Icons.text_fields),
        onPressed: () => widget.onComingSoon('Text box'),
      ),
      GlassIconButton(
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
      GlassIconButton(
        tooltip: _expanded ? 'Fewer tools' : 'More tools',
        icon: Icon(_expanded ? Icons.chevron_left : Icons.chevron_right),
        onPressed: () => setState(() => _expanded = !_expanded),
      ),
    ];
  }
}

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
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [_InkOptions(controller: c, tool: widget.tool)],
      child: GlassIconButton(
        tooltip: widget.tooltip,
        icon: Icon(widget.icon),
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
    final scheme = Theme.of(context).colorScheme;
    final glass = context.glass;
    final widths = tool == StrokeTool.pen ? _penWidths : _highlighterWidths;

    return GlassSurface(
      intensity: GlassIntensity.thick,
      padding: const EdgeInsets.all(GlassTokens.space3),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final ink in kInkColors)
                  Semantics(
                    button: true,
                    selected: ink.value == controller.colorValue,
                    label: ink.name,
                    child: GestureDetector(
                      onTap: () => controller.selectColor(ink.value),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(ink.value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ink.value == controller.colorValue
                                ? scheme.primary
                                : glass.border,
                            width: ink.value == controller.colorValue ? 3 : 1,
                          ),
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
                  Semantics(
                    button: true,
                    selected: w == controller.width,
                    label: 'Width ${w.toStringAsFixed(0)}',
                    child: GestureDetector(
                      onTap: () => controller.selectWidth(w),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: w == controller.width
                              ? scheme.primary.withValues(alpha: 0.18)
                              : null,
                          border: Border.all(
                            color: w == controller.width
                                ? scheme.primary
                                : glass.border,
                          ),
                        ),
                        child: Container(
                          width: 4 + w * 2,
                          height: 4 + w * 2,
                          decoration: BoxDecoration(
                            color: Color(controller.colorValue)
                                .withValues(alpha: 1),
                            shape: BoxShape.circle,
                          ),
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
