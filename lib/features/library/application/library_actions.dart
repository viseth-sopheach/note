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
    String? pdfPath,
  }) async {
    final notebook = await _repository.createNotebook(
      title: title.trim(),
      coverColorValue: coverColorValue,
      template: template,
      folderId: folderId,
      pdfPath: pdfPath,
    );
    _refresh();
    return notebook;
  }

  Future<Folder> createFolder({required String name, String? parentId}) async {
    final folder = await _repository.createFolder(
      name: name.trim(),
      parentId: parentId,
    );
    _refresh();
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    await _repository.renameFolder(id, name.trim());
    _refresh();
  }

  Future<void> renameNotebook(String id, String title) async {
    await _repository.renameNotebook(id, title.trim());
    _refresh();
  }

  /// [toFolderId] `null` moves the notebook to the library root.
  Future<void> moveNotebook(String id, {String? toFolderId}) async {
    await _repository.moveNotebook(id, toFolderId: toFolderId);
    _refresh();
  }

  Future<void> deleteNotebook(String id) async {
    await _repository.deleteNotebook(id);
    _refresh();
  }

  Future<void> deleteFolder(String id) async {
    await _repository.deleteFolder(id);
    _refresh();
  }

  void _refresh() {
    _ref.invalidate(foldersProvider);
    _ref.invalidate(notebooksProvider);
    _ref.invalidate(folderProvider);
    _ref.invalidate(notebookProvider);
    _ref.invalidate(allFoldersProvider);
  }
}

final libraryActionsProvider = Provider<LibraryActions>(
  (ref) => LibraryActions(ref),
);
