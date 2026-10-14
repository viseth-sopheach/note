import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/library_providers.dart';
import 'paper/paper_view.dart';

/// Placeholder editor: shows the page only. Handwriting arrives in Phase 4.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key, required this.notebookId});

  final String notebookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebook = ref.watch(notebookProvider(notebookId));

    return Scaffold(
      appBar: AppBar(title: Text(notebook.value?.title ?? 'Notebook')),
      body: notebook.when(
        data: (value) {
          if (value == null) {
            return const Center(child: Text('Notebook not found'));
          }
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.25,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(48),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PaperView(template: value.template),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not open this notebook.')),
      ),
    );
  }
}
