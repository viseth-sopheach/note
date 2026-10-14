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
import 'dialogs/confirm_delete_dialog.dart';
import 'dialogs/move_notebook_dialog.dart';
import 'dialogs/new_folder_dialog.dart';
import 'dialogs/new_notebook_dialog.dart';
import 'dialogs/rename_dialog.dart';
import 'widgets/empty_library_view.dart';
import 'widgets/folder_card.dart';
import 'widgets/item_actions_menu.dart';
import 'widgets/notebook_card.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.folderId});

  /// `null` shows the root of the library.
  final String? folderId;

  bool get _isRoot => folderId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderAsync = _isRoot ? null : ref.watch(folderProvider(folderId!));
    if (folderAsync != null &&
        folderAsync.hasValue &&
        folderAsync.value == null) {
      return const _FolderNotFoundView();
    }

    final folders = ref.watch(foldersProvider(folderId));
    final notebooks = ref.watch(notebooksProvider(folderId));
    final title = _isRoot ? 'Viseth\'s Library' : (folderAsync?.value?.name ?? '');

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
                onFolderAction: (folder, action) =>
                    _onFolderAction(context, ref, folder, action),
                onNotebookAction: (notebook, action) =>
                    _onNotebookAction(context, ref, notebook, action),
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
    ref.invalidate(folderProvider);
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
      if (!context.mounted) return;
      _logAndShowError(
        context,
        'Failed to create notebook',
        'Could not create the notebook.',
        error,
        stack,
      );
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
      if (!context.mounted) return;
      _logAndShowError(
        context,
        'Failed to create folder',
        'Could not create the folder.',
        error,
        stack,
      );
    }
  }

  Future<void> _onFolderAction(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
    ItemAction action,
  ) async {
    final actions = ref.read(libraryActionsProvider);

    switch (action) {
      case ItemAction.rename:
        final name = await RenameDialog.show(
          context,
          title: 'Rename folder',
          label: 'Folder name',
          initialValue: folder.name,
        );
        if (name == null || name == folder.name || !context.mounted) return;
        await _guard(
          context,
          'Could not rename the folder.',
          () => actions.renameFolder(folder.id, name),
        );
      case ItemAction.delete:
        final confirmed = await ConfirmDeleteDialog.show(
          context,
          title: 'Delete folder?',
          message:
              '"${folder.name}" and everything inside it will be deleted. This cannot be undone.',
        );
        if (!confirmed || !context.mounted) return;
        await _guard(
          context,
          'Could not delete the folder.',
          () => actions.deleteFolder(folder.id),
        );
      case ItemAction.move:
        break; // Moving folders is not supported yet.
    }
  }

  Future<void> _onNotebookAction(
    BuildContext context,
    WidgetRef ref,
    Notebook notebook,
    ItemAction action,
  ) async {
    final actions = ref.read(libraryActionsProvider);

    switch (action) {
      case ItemAction.rename:
        final title = await RenameDialog.show(
          context,
          title: 'Rename notebook',
          label: 'Title',
          initialValue: notebook.title,
        );
        if (title == null || title == notebook.title || !context.mounted) {
          return;
        }
        await _guard(
          context,
          'Could not rename the notebook.',
          () => actions.renameNotebook(notebook.id, title),
        );
      case ItemAction.move:
        final target = await MoveNotebookDialog.show(
          context,
          currentFolderId: notebook.folderId,
        );
        if (target == null || !context.mounted) return;
        await _guard(
          context,
          'Could not move the notebook.',
          () => actions.moveNotebook(notebook.id, toFolderId: target.folderId),
        );
      case ItemAction.delete:
        final confirmed = await ConfirmDeleteDialog.show(
          context,
          title: 'Delete notebook?',
          message: '"${notebook.title}" will be deleted. This cannot be undone.',
        );
        if (!confirmed || !context.mounted) return;
        await _guard(
          context,
          'Could not delete the notebook.',
          () => actions.deleteNotebook(notebook.id),
        );
    }
  }

  Future<void> _guard(
    BuildContext context,
    String userMessage,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stack) {
      if (!context.mounted) return;
      _logAndShowError(context, userMessage, userMessage, error, stack);
    }
  }

  void _logAndShowError(
    BuildContext context,
    String logMessage,
    String userMessage,
    Object error,
    StackTrace stack,
  ) {
    developer.log(
      logMessage,
      name: 'library',
      error: error,
      stackTrace: stack,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(userMessage)));
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.isRoot,
    required this.folders,
    required this.notebooks,
    required this.onNewNotebook,
    required this.onNewFolder,
    required this.onFolderAction,
    required this.onNotebookAction,
  });

  final bool isRoot;
  final List<Folder> folders;
  final List<Notebook> notebooks;
  final VoidCallback onNewNotebook;
  final VoidCallback onNewFolder;
  final void Function(Folder folder, ItemAction action) onFolderAction;
  final void Function(Notebook notebook, ItemAction action) onNotebookAction;

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
                return ItemActionsMenu(
                  onSelected: (action) => onFolderAction(folder, action),
                  child: FolderCard(
                    folder: folder,
                    onTap: () => context.push(AppRoutes.folder(folder.id)),
                  ),
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
                return ItemActionsMenu(
                  canMove: true,
                  onSelected: (action) => onNotebookAction(notebook, action),
                  child: NotebookCard(
                    notebook: notebook,
                    onTap: () => context.push(AppRoutes.notebook(notebook.id)),
                  ),
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

class _FolderNotFoundView extends StatelessWidget {
  const _FolderNotFoundView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folder')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This folder no longer exists.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.library),
              child: const Text('Back to library'),
            ),
          ],
        ),
      ),
    );
  }
}