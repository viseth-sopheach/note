import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/folder.dart';
import '../domain/library_repository.dart';
import '../domain/notebook.dart';
import '../domain/paper_template.dart';
import 'library_providers.dart';

/// Write operations for the library. Every change refreshes the cached lists
/// so the UI never shows stale data.
class LibraryActions {
  LibraryActions(this._ref);

  final Ref _ref;

  LibraryRepository get _repository => _ref.read(libraryRepositoryProvider);

  Future<Notebook> createNotebook({
    required String title,
    required int coverColorValue,
    required PaperTemplate template,
    String? folderId,
  }) async {
    final notebook = await _repository.createNotebook(
      title: title.trim(),
      coverColorValue: coverColorValue,
      template: template,
      folderId: folderId,
    );
    _refresh();
    return notebook;
  }

  Future<Folder> createFolder({required String name, String? parentId}) async {
    final folder =
        await _repository.createFolder(name: name.trim(), parentId: parentId);
    _refresh();
    return folder;
  }

  void _refresh() {
    _ref.invalidate(foldersProvider);
    _ref.invalidate(notebooksProvider);
  }
}

final libraryActionsProvider =
    Provider<LibraryActions>((ref) => LibraryActions(ref));