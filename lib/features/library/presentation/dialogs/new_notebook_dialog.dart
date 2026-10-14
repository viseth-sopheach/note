import 'package:flutter/material.dart';

import '../../domain/name_rules.dart';
import '../../domain/paper_template.dart';
import '../cover_palette.dart';

final class NewNotebookResult {
  const NewNotebookResult({
    required this.title,
    required this.coverColorValue,
    required this.template,
  });

  final String title;
  final int coverColorValue;
  final PaperTemplate template;
}

class NewNotebookDialog extends StatefulWidget {
  const NewNotebookDialog({super.key});

  /// Returns the chosen settings, or null if cancelled.
  static Future<NewNotebookResult?> show(BuildContext context) =>
      showDialog<NewNotebookResult>(
        context: context,
        builder: (_) => const NewNotebookDialog(),
      );

  @override
  State<NewNotebookDialog> createState() => _NewNotebookDialogState();
}

class _NewNotebookDialogState extends State<NewNotebookDialog> {
  static const String _defaultTitle = 'Untitled notebook';

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: _defaultTitle);

  Color _cover = CoverPalette.colors.first;
  PaperTemplate _template = PaperTemplate.blank;

  @override
  void initState() {
    super.initState();
    _titleController.selection =
        const TextSelection(baseOffset: 0, extentOffset: _defaultTitle.length);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      NewNotebookResult(
        title: _titleController.text.trim(),
        coverColorValue: _cover.toARGB32(),
        template: _template,
      ),
    );
  }

  static IconData _iconFor(PaperTemplate template) => switch (template) {
        PaperTemplate.blank => Icons.crop_portrait,
        PaperTemplate.lined => Icons.view_headline,
        PaperTemplate.dotted => Icons.more_horiz,
        PaperTemplate.grid => Icons.grid_4x4,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('New notebook'),
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                maxLength: kMaxNameLength,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: validateName,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Text('Cover', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in CoverPalette.colors)
                    _CoverSwatch(
                      color: color,
                      selected: color == _cover,
                      onTap: () => setState(() => _cover = color),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Paper', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final template in PaperTemplate.values)
                    ChoiceChip(
                      avatar: Icon(_iconFor(template), size: 18),
                      label: Text(template.label),
                      selected: template == _template,
                      onSelected: (_) => setState(() => _template = template),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

class _CoverSwatch extends StatelessWidget {
  const _CoverSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Cover color',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected
              ? Icon(Icons.check, size: 20, color: CoverPalette.onColor(color))
              : null,
        ),
      ),
    );
  }
}