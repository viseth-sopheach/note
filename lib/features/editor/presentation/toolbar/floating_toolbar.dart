import 'package:flutter/material.dart';

import '../../../../app/glass/glass_icon_button.dart';
import '../../../../app/glass/glass_menu.dart';
import '../../../../app/glass/glass_pill.dart';
import '../../../../app/glass/glass_surface.dart';
import '../../../../app/glass/glass_svg_icon.dart';
import '../../../../app/glass/glass_theme.dart';
import '../../../../app/glass/glass_tokens.dart';
import '../../application/drawing_controller.dart';
import '../../application/measure_controller.dart';
import '../../domain/stroke_tool.dart';
import '../../domain/tip_size.dart';
import 'ink_palette.dart';
import 'tool_icons.dart';

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
    required this.onAddTemplate,
    required this.onToggleMeasure,
    required this.onSettings,
    required this.onDuplicatePage,
    required this.onDeletePage,
    required this.textActive,
    required this.onTextTool,
    required this.onToolPicked,
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
  final VoidCallback onAddTemplate;
  final void Function(MeasureKind kind) onToggleMeasure;
  final VoidCallback onSettings;
  final VoidCallback onDuplicatePage;

  /// Null hides the delete item (only one page left).
  final VoidCallback? onDeletePage;
  final bool busy;

  final bool textActive;
  final VoidCallback onTextTool;

  /// Called before any drawing tool is selected (leaves the text tool).
  final VoidCallback onToolPicked;

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
      GlassMenuItem(
        value: 'template',
        icon: Icons.article_outlined,
        label: 'Add page with template…',
      ),
    ]);
    switch (v) {
      case 'pdf':
        widget.onImportPdf();
      case 'image':
        widget.onInsertImage();
      case 'page':
        widget.onAddPage();
      case 'template':
        widget.onAddTemplate();
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
    Widget tool(StrokeTool t, Widget icon, String tip) => GlassIconButton(
      tooltip: tip,
      icon: icon,
      selected: !widget.textActive && _c.tool == t,
      onPressed: () {
        widget.onToolPicked();
        _c.selectTool(t);
      },
    );

    return [
      _InkToolButton(
        controller: _c,
        tool: StrokeTool.pen,
        icon: const GlassSvgIcon(ToolIcons.pen),
        tooltip: 'Pen',
        textActive: widget.textActive,
        onPicked: widget.onToolPicked,
      ),
      _InkToolButton(
        controller: _c,
        tool: StrokeTool.highlighter,
        icon: const GlassSvgIcon(ToolIcons.highlighter),
        tooltip: 'Highlighter',
        textActive: widget.textActive,
        onPicked: widget.onToolPicked,
      ),
      tool(StrokeTool.eraser, const GlassSvgIcon(ToolIcons.eraser), 'Eraser'),
      tool(
        StrokeTool.select,
        const GlassSvgIcon(ToolIcons.lasso),
        'Lasso select',
      ),
      GlassIconButton(
        tooltip: 'Text box',
        icon: const Icon(Icons.text_fields),
        selected: widget.textActive,
        onPressed: widget.onTextTool,
      ),
      if (_expanded) ...[
        tool(StrokeTool.line, const Icon(Icons.horizontal_rule), 'Line'),
        tool(
          StrokeTool.rectangle,
          const Icon(Icons.rectangle_outlined),
          'Rectangle',
        ),
        tool(StrokeTool.ellipse, const Icon(Icons.circle_outlined), 'Ellipse'),
        tool(
          StrokeTool.triangle,
          const Icon(Icons.change_history_outlined),
          'Triangle',
        ),
        tool(StrokeTool.arrow, const Icon(Icons.arrow_right_alt), 'Arrow'),
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
    required this.textActive,
    required this.onPicked,
  });

  final DrawingController controller;
  final StrokeTool tool;
  final Widget icon;
  final String tooltip;
  final bool textActive;
  final VoidCallback onPicked;

  @override
  State<_InkToolButton> createState() => _InkToolButtonState();
}

class _InkToolButtonState extends State<_InkToolButton> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final selected = !widget.textActive && c.tool == widget.tool;

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
        icon: widget.icon,
        selected: selected,
        onPressed: () {
          if (!selected) {
            widget.onPicked();
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
            Builder(
              builder: (context) {
                final percent = TipSize.percentFor(tool, controller.width);
                final dot = controller.width.clamp(2.0, 28.0).toDouble();
                return SizedBox(
                  width: 248,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text('Tip size'),
                          const Spacer(),
                          Text('$percent%'),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              min: TipSize.minPercent.toDouble(),
                              max: TipSize.maxPercent.toDouble(),
                              divisions:
                                  TipSize.maxPercent - TipSize.minPercent,
                              value: percent.toDouble(),
                              label: '$percent%',
                              onChanged: (v) => controller.selectWidth(
                                TipSize.widthFor(tool, v.round()),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: Center(
                              child: Container(
                                width: dot,
                                height: dot,
                                decoration: BoxDecoration(
                                  color: Color(controller.colorValue)
                                      .withValues(alpha: 1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
