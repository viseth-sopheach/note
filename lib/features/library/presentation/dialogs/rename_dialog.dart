import 'package:flutter/material.dart';

import '../../domain/name_rules.dart';

class RenameDialog extends StatefulWidget {
  const RenameDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initialValue,
  });

  final String title;
  final String label;
  final String initialValue;

  /// Returns the trimmed new name, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    required String initialValue,
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        RenameDialog(title: title, label: label, initialValue: initialValue),
  );

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialValue.length,
      );
  }

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
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: kMaxNameLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: widget.label),
          validator: validateName,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Rename')),
      ],
    );
  }
}
