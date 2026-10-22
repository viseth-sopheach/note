import 'package:flutter/material.dart';

import '../../../../app/glass/glass_button.dart';
import '../../../../app/glass/glass_dialog.dart';
import '../../domain/name_rules.dart';

class NewFolderDialog extends StatefulWidget {
  const NewFolderDialog({super.key});

  /// Returns the trimmed folder name, or null if cancelled.
  static Future<String?> show(BuildContext context) => showGlassDialog<String>(
    context: context,
    builder: (_) => const NewFolderDialog(),
  );

  @override
  State<NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<NewFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: const Text('New folder'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: kMaxNameLength,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Folder name'),
          validator: validateName,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        GlassButton(
          label: 'Cancel',
          kind: GlassButtonKind.plain,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassButton(label: 'Create', onPressed: _submit),
      ],
    );
  }
}
