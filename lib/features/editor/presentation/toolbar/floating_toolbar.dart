import 'package:flutter/material.dart';

import '../../../../app/glass/glass_icon_button.dart';
import '../../../../app/glass/glass_menu.dart';
import '../../../../app/glass/glass_pill.dart';
import '../../../../app/glass/glass_surface.dart';
import '../../../../app/glass/glass_tokens.dart';
import '../../application/drawing_controller.dart';
import '../../application/measure_controller.dart';
import '../../domain/stroke_tool.dart';
import 'ink_palette.dart';

const List<double> _penWidths = [1, 2, 4, 6];
const List<double> _highlighterWidths = [2, 3, 4];
const double _compactBreakpoint = 600;
const double _popoverWidth = 264;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _compactBreakpoint;
          return ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Row(
              children: [
                _leftPill(compact),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: GlassPill(children: _tools()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                compact ? _compactMenu() : _rightPill(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _leftPill(bool compact) {
    return GlassPill(
      children: [
        GlassIconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left),
          onPressed: widget.onBack,
        ),
        if (!compact)
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
    );
  }

  Widget _rightPill() {
    return GlassPill(
      children: [
        GlassIconButton(
          tooltip: 'Export PDF (Ctrl+E)',
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: widget.busy ? null : widget.onExport,
        ),
        _MenuButton(
          icon: Icons.add,
          tooltip: 'Insert',
          items: const [
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
          ],
          onSelected: _onAction,
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
          onPressed: () => widget.onFingerDrawsChanged(!widget.fingerDraws),
        ),
        _MenuButton(
          icon: Icons.more_horiz,
          tooltip: 'More',
          items: const [
            GlassMenuItem(
              value: 'ruler',
              icon: Icons.straighten,
              label: 'Ruler',
            ),
            GlassMenuItem(
              value: 'protractor',
              icon: Icons.architecture,
              label: 'Protractor',
            ),
            GlassMenuItem(
              value: 'settings',
              icon: Icons.settings_outlined,
              label: 'Settings',
            ),
          ],
          onSelected: _onAction,
        ),
      ],
    );
  }

  Widget _compactMenu() {
    return GlassPill(
      children: [
        _MenuButton(
          icon: Icons.more_horiz,
          tooltip: 'More',
          items: [
            const GlassMenuItem(
              value: 'pages',
              icon: Icons.grid_view_outlined,
              label: 'Pages',
            ),
            const GlassMenuItem(
              value: 'export',
              icon: Icons.picture_as_pdf_outlined,
              label: 'Export PDF',
            ),
            const GlassMenuItem(
              value: 'pdf',
              icon: Icons.upload_file,
              label: 'Import PDF from device',
            ),
            const GlassMenuItem(
              value: 'image',
              icon: Icons.image_outlined,
              label: 'Insert image',
            ),
            const GlassMenuItem(
              value: 'page',
              icon: Icons.note_add_outlined,
              label: 'Add page',
            ),
            GlassMenuItem(
              value: 'finger',
              icon: widget.fingerDraws
                  ? Icons.touch_app_outlined
                  : Icons.do_not_touch_outlined,
              label: widget.fingerDraws ? 'Finger draws' : 'Stylus only',
            ),
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
            const GlassMenuItem(
              value: 'settings',
              icon: Icons.settings_outlined,
              label: 'Settings',
            ),
          ],
          onSelected: _onAction,
        ),
      ],
    );
  }

  void _onAction(String value) {
    switch (value) {
      case 'pages':
        widget.onPages();
      case 'export':
        if (!widget.busy) widget.onExport();
      case 'pdf':
        widget.onImportPdf();
      case 'image':
        widget.onInsertImage();
      case 'page':
        widget.onAddPage();
      case 'finger':
        widget.onFingerDrawsChanged(!widget.fingerDraws);
      case 'ruler':
        widget.onToggleMeasure(MeasureKind.ruler);
      case 'protractor':
        widget.onToggleMeasure(MeasureKind.protractor);
      case 'settings':
        widget.onSettings();
    }
  }

  List<Widget> _tools() {
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

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.tooltip,
    required this.items,
    required this.onSelected,
  });

  final IconData icon;
  final String tooltip;
  final List<GlassMenuItem<String>> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchor) => GlassIconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: () async {
          final box = anchor.findRenderObject()! as RenderBox;
          final origin = box.localToGlobal(Offset(0, box.size.height + 6));
          final value = await showGlassMenu<String>(
            context: anchor,
            position: origin,
            items: items,
          );
          if (value != null) onSelected(value);
        },
      ),
    );
  }
}

class _InkToolButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchor) {
        final selected = controller.tool == tool;
        return GlassIconButton(
          tooltip: tooltip,
          icon: Icon(icon),
          selected: selected,
          onPressed: () {
            if (!selected) {
              controller.selectTool(tool);
              return;
            }
            _showInkPopover(anchor, controller, tool);
          },
        );
      },
    );
  }
}

Future<void> _showInkPopover(
  BuildContext anchor,
  DrawingController controller,
  StrokeTool tool,
) {
  final box = anchor.findRenderObject()! as RenderBox;
  final origin = box.localToGlobal(Offset(0, box.size.height + 8));
  final still = MediaQuery.disableAnimationsOf(anchor);

  return showGeneralDialog<void>(
    context: anchor,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: still ? Duration.zero : GlassTokens.menu,
    pageBuilder: (context, _, _) =>
        _InkPopover(origin: origin, controller: controller, tool: tool),
    transitionBuilder: (context, animation, _, child) {
      final curved = animation.drive(CurveTween(curve: GlassTokens.curve));
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          alignment: Alignment.topCenter,
          scale: curved.drive(Tween(begin: 0.94, end: 1.0)),
          child: child,
        ),
      );
    },
  );
}

class _InkPopover extends StatelessWidget {
  const _InkPopover({
    required this.origin,
    required this.controller,
    required this.tool,
  });

  final Offset origin;
  final DrawingController controller;
  final StrokeTool tool;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final left = origin.dx
        .clamp(8.0, size.width - _popoverWidth - 8)
        .toDouble();

    return Stack(
      children: [
        Positioned(
          left: left,
          top: origin.dy,
          width: _popoverWidth,
          child: Material(
            type: MaterialType.transparency,
            child: GlassSurface(
              intensity: GlassIntensity.thick,
              padding: const EdgeInsets.all(12),
              child: _InkOptions(controller: controller, tool: tool),
            ),
          ),
        ),
      ],
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
                      width: 30,
                      height: 30,
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
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: w == controller.width
                            ? colors.primary.withValues(alpha: 0.18)
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
    );
  }
}
