import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../application/library_actions.dart';
import '../application/library_providers.dart';
import '../domain/folder.dart';
import '../domain/notebook.dart';
import 'dialogs/new_folder_dialog.dart';
import 'dialogs/new_notebook_dialog.dart';
import 'widgets/empty_library_view.dart';
import 'widgets/folder_card.dart';
import 'widgets/notebook_card.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.folderId});

  /// `null` shows the root of the library.
  final String? folderId;

  bool get _isRoot => folderId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider(folderId));
    final notebooks = ref.watch(notebooksProvider(folderId));
    final title = _isRoot
        ? 'Library'
        : (ref.watch(folderProvider(folderId!)).value?.name ?? '');

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _createNotebook(context, ref),
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          control: true,
          shift: true,
        ): () => _createFolder(context, ref),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: 'New folder (Ctrl+Shift+N)',
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () => _createFolder(context, ref),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            tooltip: 'New notebook (Ctrl+N)',
            onPressed: () => _createNotebook(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('New notebook'),
          ),
          body: folders.when(
            data: (folderList) => notebooks.when(
              data: (notebookList) => _LibraryContent(
                isRoot: _isRoot,
                folders: folderList,
                notebooks: notebookList,
                onNewNotebook: () => _createNotebook(context, ref),
                onNewFolder: () => _createFolder(context, ref),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorView(onRetry: () => _reload(ref)),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorView(onRetry: () => _reload(ref)),
          ),
        ),
      ),
    );
  }

  void _reload(WidgetRef ref) {
    ref.invalidate(foldersProvider);
    ref.invalidate(notebooksProvider);
  }

  Future<void> _createNotebook(BuildContext context, WidgetRef ref) async {
    final result = await NewNotebookDialog.show(context);
    if (result == null || !context.mounted) return;

    try {
      final notebook = await ref.read(libraryActionsProvider).createNotebook(
            title: result.title,
            coverColorValue: result.coverColorValue,
            template: result.template,
            folderId: folderId,
          );
      if (!context.mounted) return;
      await context.push(AppRoutes.notebook(notebook.id));
    } catch (error, stack) {
      developer.log(
        'Failed to create notebook',
        name: 'library',
        error: error,
        stackTrace: stack,
      );
      if (!context.mounted) return;
      _showError(context, 'Could not create the notebook.');
    }
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final name = await NewFolderDialog.show(context);
    if (name == null || !context.mounted) return;

    try {
      await ref
          .read(libraryActionsProvider)
          .createFolder(name: name, parentId: folderId);
    } catch (error, stack) {
      developer.log(
        'Failed to create folder',
        name: 'library',
        error: error,
        stackTrace: stack,
      );
      if (!context.mounted) return;
      _showError(context, 'Could not create the folder.');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.isRoot,
    required this.folders,
    required this.notebooks,
    required this.onNewNotebook,
    required this.onNewFolder,
  });

  final bool isRoot;
  final List<Folder> folders;
  final List<Notebook> notebooks;
  final VoidCallback onNewNotebook;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty && notebooks.isEmpty) {
      return EmptyLibraryView(
        isRoot: isRoot,
        onNewNotebook: onNewNotebook,
        onNewFolder: onNewFolder,
      );
    }

    return CustomScrollView(
      slivers: [
        if (folders.isNotEmpty) ...[
          const _SectionHeader('Folders'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisExtent: 56,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return FolderCard(
                  folder: folder,
                  onTap: () => context.push(AppRoutes.folder(folder.id)),
                );
              },
            ),
          ),
        ],
        if (notebooks.isNotEmpty) ...[
          const _SectionHeader('Notebooks'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                childAspectRatio: 0.7,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: notebooks.length,
              itemBuilder: (context, index) {
                final notebook = notebooks[index];
                return NotebookCard(
                  notebook: notebook,
                  onTap: () => context.push(AppRoutes.notebook(notebook.id)),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Something went wrong while loading your library.'),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}