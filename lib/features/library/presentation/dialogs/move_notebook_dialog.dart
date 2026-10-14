import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/library_providers.dart';
import '../../domain/folder.dart';

/// Wraps the destination so "root" (null) differs from "cancelled" (null).
final class MoveTarget {
  const MoveTarget(this.folderId);

  final String? folderId;
}

class MoveNotebookDialog extends ConsumerWidget {
  const MoveNotebookDialog({super.key, required this.currentFolderId});

  final String? currentFolderId;

  /// Returns the chosen destination, or null if cancelled.
  static Future<MoveTarget?> show(
    BuildContext context, {
    required String? currentFolderId,
  }) =>
      showDialog<MoveTarget>(
        context: context,
        builder: (_) => MoveNotebookDialog(currentFolderId: currentFolderId),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(allFoldersProvider);

    return AlertDialog(
      title: const Text('Move to'),
      content: SizedBox(
        width: 360,
        child: folders.when(
          data: (list) => _TargetList(
            folders: list,
            currentFolderId: currentFolderId,
          ),
          loading: () => const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const Text('Could not load folders.'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _TargetList extends StatelessWidget {
  const _TargetList({required this.folders, required this.currentFolderId});

  final List<Folder> folders;
  final String? currentFolderId;

  static String _pathOf(Folder folder, Map<String, Folder> byId) {
    final parts = <String>[folder.name];
    var parent = folder.parentId;
    while (parent != null) {
      final next = byId[parent];
      if (next == null) break;
      parts.add(next.name);
      parent = next.parentId;
    }
    return parts.reversed.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final f in folders) f.id: f};
    final entries = [
      for (final f in folders) (id: f.id, path: _pathOf(f, byId)),
    ]..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    Widget tile({
      required String? id,
      required String label,
      required IconData icon,
    }) {
      final isCurrent = id == currentFolderId;
      return ListTile(
        leading: Icon(icon),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: isCurrent ? const Icon(Icons.check) : null,
        enabled: !isCurrent,
        onTap: () => Navigator.of(context).pop(MoveTarget(id)),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView(
        shrinkWrap: true,
        children: [
          tile(id: null, label: 'Library', icon: Icons.home_outlined),
          for (final entry in entries)
            tile(
              id: entry.id,
              label: entry.path,
              icon: Icons.folder_outlined,
            ),
        ],
      ),
    );
  }
}