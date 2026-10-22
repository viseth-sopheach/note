import 'package:flutter/material.dart';

import '../../../../app/glass/glass_button.dart';
import '../../../../app/glass/glass_dialog.dart';

abstract final class ConfirmDeleteDialog {
  /// Returns true only when the user confirms.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showGlassDialog<bool>(
      context: context,
      builder: (context) => GlassDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          GlassButton(
            autofocus: true,
            label: 'Cancel',
            kind: GlassButtonKind.plain,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          GlassButton(
            label: 'Delete',
            kind: GlassButtonKind.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
