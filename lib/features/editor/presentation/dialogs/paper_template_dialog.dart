import 'package:flutter/material.dart';

import '../../../../app/glass/glass_button.dart';
import '../../../../app/glass/glass_dialog.dart';
import '../../../library/domain/paper_template.dart';
import '../paper/paper_colors.dart';

/// Lets the user pick a paper template, with a small preview of each.
class PaperTemplateDialog extends StatefulWidget {
  const PaperTemplateDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final PaperTemplate initial;

  /// Returns the chosen template, or null if cancelled.
  static Future<PaperTemplate?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required PaperTemplate initial,
  }) => showGlassDialog<PaperTemplate>(
    context: context,
    builder: (_) => PaperTemplateDialog(
      title: title,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );

  @override
  State<PaperTemplateDialog> createState() => _PaperTemplateDialogState();
}

class _PaperTemplateDialogState extends State<PaperTemplateDialog> {
  late PaperTemplate _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: Text(widget.title),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final template in PaperTemplate.values)
            _TemplateTile(
              template: template,
              selected: template == _selected,
              onTap: () => setState(() => _selected = template),
            ),
        ],
      ),
      actions: [
        GlassButton(
          label: 'Cancel',
          kind: GlassButtonKind.plain,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassButton(
          autofocus: true,
          label: widget.confirmLabel,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final PaperTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '${template.label} paper',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 108,
                decoration: BoxDecoration(
                  color: PaperColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? colors.primary : colors.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(painter: _PreviewPainter(template)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                template.label,
                style: textTheme.labelLarge?.copyWith(
                  color: selected ? colors.primary : null,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(this.template);

  final PaperTemplate template;

  static const double _spacing = 12;
  static const Color _ink = Color(0xFFB8C0C8);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _ink
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    switch (template) {
      case PaperTemplate.blank:
        break;
      case PaperTemplate.lined:
        for (var y = _spacing * 2; y < size.height; y += _spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
      case PaperTemplate.grid:
        for (var y = _spacing; y < size.height; y += _spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        for (var x = _spacing; x < size.width; x += _spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
      case PaperTemplate.dotted:
        final dot = Paint()..color = _ink;
        for (var y = _spacing; y < size.height; y += _spacing) {
          for (var x = _spacing; x < size.width; x += _spacing) {
            canvas.drawCircle(Offset(x, y), 1, dot);
          }
        }
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) =>
      oldDelegate.template != template;
}
