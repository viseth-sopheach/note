import 'package:flutter/material.dart';

import '../../../app/glass/glass_button.dart';
import '../../../app/glass/glass_dialog.dart';
import '../../../app/glass/glass_segmented_control.dart';
import '../domain/export_options.dart';

class ExportOptionsDialog extends StatefulWidget {
  const ExportOptionsDialog({super.key, this.initial = const ExportOptions()});

  final ExportOptions initial;

  /// Returns the chosen options, or null if cancelled.
  static Future<ExportOptions?> show(
    BuildContext context, {
    ExportOptions initial = const ExportOptions(),
  }) => showGlassDialog<ExportOptions>(
    context: context,
    builder: (_) => ExportOptionsDialog(initial: initial),
  );

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  late ExportOptions _options = widget.initial;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassDialog(
      title: const Text('Export PDF'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paper', style: text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final paper in ExportPaper.values)
                ChoiceChip(
                  label: Text(paper.label),
                  selected: _options.paper == paper,
                  onSelected: (_) =>
                      setState(() => _options = _options.copyWith(paper: paper)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Appearance', style: text.titleSmall),
          const SizedBox(height: 8),
          GlassSegmentedControl<ExportColorMode>(
            segments: const [
              GlassSegment(
                value: ExportColorMode.light,
                label: 'Light',
                icon: Icons.light_mode_outlined,
              ),
              GlassSegment(
                value: ExportColorMode.dark,
                label: 'Dark',
                icon: Icons.dark_mode_outlined,
              ),
            ],
            selected: _options.colorMode,
            onChanged: (m) =>
                setState(() => _options = _options.copyWith(colorMode: m)),
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
          label: 'Export',
          onPressed: () => Navigator.of(context).pop(_options),
        ),
      ],
    );
  }
}