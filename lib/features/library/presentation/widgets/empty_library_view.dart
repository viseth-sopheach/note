import 'package:flutter/material.dart';

import '../../../../app/glass/glass_button.dart';
import '../../../../app/glass/glass_surface.dart';
import '../../../../app/glass/glass_tokens.dart';

class EmptyLibraryView extends StatelessWidget {
  final bool isRoot;
  final VoidCallback onNewNotebook;
  final VoidCallback onNewFolder;

  const EmptyLibraryView({
    super.key,
    required this.isRoot,
    required this.onNewNotebook,
    required this.onNewFolder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final title = isRoot ? 'Your library is empty' : 'This folder is empty';
    final subtitle = isRoot
        ? 'Create a notebook or folder to start organizing your notes and documents.'
        : 'Add a notebook or subfolder to get started.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlassSurface(
              radius: GlassTokens.radiusPill,
              child: SizedBox(
                width: 88,
                height: 88,
                child: Icon(
                  Icons.menu_book_outlined,
                  size: 40,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 32.0),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12.0,
              runSpacing: 12.0,
              children: [
                GlassButton(
                  label: 'New folder',
                  icon: Icons.create_new_folder_outlined,
                  kind: GlassButtonKind.plain,
                  onPressed: onNewFolder,
                ),
                GlassButton(
                  label: 'New notebook',
                  icon: Icons.add,
                  onPressed: onNewNotebook,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
