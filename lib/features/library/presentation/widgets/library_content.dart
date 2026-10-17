import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../domain/folder.dart';
import '../../domain/notebook.dart';
import 'empty_library_view.dart';
import 'folder_card.dart';
import 'item_actions_menu.dart';
import 'notebook_card.dart';

/// Responsive folder and notebook grids of the library.
class LibraryContent extends StatelessWidget {
  const LibraryContent({
    super.key,
    required this.isRoot,
    required this.folders,
    required this.notebooks,
    required this.showCovers,
    required this.compact,
    required this.onNewNotebook,
    required this.onNewFolder,
    required this.onFolderAction,
    required this.onNotebookAction,
  });

  final bool isRoot;
  final List<Folder> folders;
  final List<Notebook> notebooks;
  final bool showCovers;
  final bool compact;
  final VoidCallback onNewNotebook;
  final VoidCallback onNewFolder;
  final void Function(Folder folder, ItemAction action) onFolderAction;
  final void Function(Notebook notebook, ItemAction action) onNotebookAction;

  static const double _maxWidth = 1200;

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty && notebooks.isEmpty) {
      return EmptyLibraryView(
        isRoot: isRoot,
        onNewNotebook: onNewNotebook,
        onNewFolder: onNewFolder,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = width >= 1024
            ? 32.0
            : width >= 600
            ? 24.0
            : 16.0;
        final side = math.max(gutter, (width - _maxWidth) / 2);
        final gap = compact ? 10.0 : 16.0;

        return CustomScrollView(
          slivers: [
            if (folders.isNotEmpty) ...[
              _SectionHeader(
                label: 'Folders',
                count: folders.length,
                side: side,
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: compact ? 52 : 60,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                  ),
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ItemActionsMenu(
                      canMove: true,
                      canShare: true,
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
              _SectionHeader(
                label: 'Notebooks',
                count: notebooks.length,
                side: side,
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 0, side, 104),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: width < 600 ? 170 : 200,
                    childAspectRatio: 0.72,
                    mainAxisSpacing: gap + 4,
                    crossAxisSpacing: gap,
                  ),
                  itemCount: notebooks.length,
                  itemBuilder: (context, index) {
                    final notebook = notebooks[index];
                    return ItemActionsMenu(
                      canMove: true,
                      onSelected: (action) =>
                          onNotebookAction(notebook, action),
                      child: NotebookCard(
                        notebook: notebook,
                        showCover: showCovers,
                        onTap: () =>
                            context.push(AppRoutes.notebook(notebook.id)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.side,
  });

  final String label;
  final int count;
  final double side;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, 24, side, 12),
        child: Row(
          children: [
            Text(
              label,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}