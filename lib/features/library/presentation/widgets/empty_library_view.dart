import 'package:flutter/material.dart';

class EmptyLibraryView extends StatelessWidget {
  const EmptyLibraryView({
    super.key,
    required this.isRoot,
    required this.onNewNotebook,
    required this.onNewFolder,
  });

  final bool isRoot;
  final VoidCallback onNewNotebook;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: colors.outline),
          const SizedBox(height: 16),
          Text(
            isRoot ? 'No notebooks yet' : 'This folder is empty',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Create a notebook to start writing.',
            style: textTheme.bodyMedium?.copyWith(color: colors.outline),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onNewNotebook,
                icon: const Icon(Icons.add),
                label: const Text('New notebook'),
              ),
              OutlinedButton.icon(
                onPressed: onNewFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('New folder'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}