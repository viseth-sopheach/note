import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/library_providers.dart';

/// Placeholder until the handwriting engine arrives in Phase 4.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key, required this.notebookId});

  final String notebookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebook = ref.watch(notebookProvider(notebookId));

    return Scaffold(
      appBar: AppBar(title: Text(notebook.value?.title ?? 'Notebook')),
      body: notebook.when(
        data: (value) => Center(
          child: Text(
            value == null
                ? 'Notebook not found'
                : 'Paper: ${value.template.label}\nThe editor arrives in Phase 4.',
            textAlign: TextAlign.center,
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not open this notebook.')),
      ),
    );
  }
}