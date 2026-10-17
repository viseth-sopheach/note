import 'folder.dart';
import 'notebook.dart';
import 'paper_template.dart';

abstract interface class LibraryRepository {
  Future<List<Folder>> getFolders({String? parentId});

  Future<List<Notebook>> getNotebooks({String? folderId});

  Future<Folder> createFolder({required String name, String? parentId});

  Future<Notebook> createNotebook({
    required String title,
    required int coverColorValue,
    required PaperTemplate template,
    String? folderId,
    String? pdfPath,
  });

  Future<void> renameFolder(String id, String name);

  Future<void> renameNotebook(String id, String title);

  Future<void> moveNotebook(String id, {String? toFolderId});

  Future<void> deleteNotebook(String id);

  Future<void> deleteFolder(String id);

  Future<Folder?> getFolder(String id);

  Future<Notebook?> getNotebook(String id);

  Future<List<Folder>> getAllFolders();

  Future<List<Folder>> searchFolders(String query);

  Future<List<Notebook>> searchNotebooks(String query);
}
