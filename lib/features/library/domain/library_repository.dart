import 'folder.dart';
import 'notebook.dart';
import 'paper_template.dart';

/// Storage contract for the library. The UI depends on this interface only.
abstract interface class LibraryRepository {
  /// Folders directly inside [parentId] (`null` = root), sorted by name.
  Future<List<Folder>> getFolders({String? parentId});

  /// Notebooks directly inside [folderId] (`null` = root), newest edit first.
  Future<List<Notebook>> getNotebooks({String? folderId});

  Future<Folder> createFolder({required String name, String? parentId});

  Future<Notebook> createNotebook({
    required String title,
    required int coverColorValue,
    required PaperTemplate template,
    String? folderId,
  });

  Future<void> renameFolder(String id, String name);

  Future<void> renameNotebook(String id, String title);

  Future<void> moveNotebook(String id, {String? toFolderId});

  Future<void> deleteNotebook(String id);

  /// Deletes the folder, all its subfolders and all notebooks inside them.
  Future<void> deleteFolder(String id);

  Future<Folder?> getFolder(String id);

  Future<Notebook?> getNotebook(String id);

  /// Every folder in the library, sorted by name.
  Future<List<Folder>> getAllFolders();
}
