import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/glass/glass_divider.dart';
import '../../../editor/domain/stroke_tool.dart';
import '../../../editor/presentation/toolbar/ink_palette.dart';
import '../../../library/domain/paper_template.dart';
import '../../application/settings_providers.dart';
import '../../domain/app_settings.dart';
import '../widgets/settings_widgets.dart';

class PaperSection extends ConsumerWidget {
  const PaperSection({super.key});

  static final List<ColorOption> _inkOptions = [
    for (final c in kInkColors) ColorOption(c.name, Color(c.value)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    String widthLabel(double w) => 'Width ${w.toStringAsFixed(0)}';

    return SettingsSection(
      title: 'Note-taking & Paper',
      icon: Icons.edit_note_outlined,
      children: [
        SettingsChoiceTile<PaperTemplate>(
          title: 'Default paper',
          subtitle: 'Used when you create a new notebook',
          value: settings.defaultTemplate,
          options: [
            for (final t in PaperTemplate.values) (value: t, label: t.label),
          ],
          onChanged: (t) =>
              notifier.update((s) => s.copyWith(defaultTemplate: t)),
        ),
        const GlassDivider(),
        SettingsChoiceTile<StrokeTool>(
          title: 'Default tool',
          value: settings.defaultTool,
          options: const [
            (value: StrokeTool.pen, label: 'Pen'),
            (value: StrokeTool.highlighter, label: 'Highlighter'),
          ],
          onChanged: (t) => notifier.update((s) => s.copyWith(defaultTool: t)),
        ),
        const GlassDivider(),
        SettingsColorRow(
          title: 'Pen color',
          options: _inkOptions,
          selected: Color(settings.penColorValue),
          onChanged: (c) =>
              notifier.update((s) => s.copyWith(penColorValue: c.toARGB32())),
        ),
        const GlassDivider(),
        SettingsChoiceTile<double>(
          title: 'Pen thickness',
          value: settings.penWidth,
          options: [
            for (final w in AppSettings.penWidths)
              (value: w, label: widthLabel(w)),
          ],
          onChanged: (w) => notifier.update((s) => s.copyWith(penWidth: w)),
        ),
        const GlassDivider(),
        SettingsColorRow(
          title: 'Highlighter color',
          options: _inkOptions,
          selected: Color(settings.highlighterColorValue),
          onChanged: (c) => notifier.update(
            (s) => s.copyWith(highlighterColorValue: c.toARGB32()),
          ),
        ),
        const GlassDivider(),
        SettingsChoiceTile<double>(
          title: 'Highlighter thickness',
          value: settings.highlighterWidth,
          options: [
            for (final w in AppSettings.highlighterWidths)
              (value: w, label: widthLabel(w)),
          ],
          onChanged: (w) =>
              notifier.update((s) => s.copyWith(highlighterWidth: w)),
        ),
      ],
    );
  }
}
