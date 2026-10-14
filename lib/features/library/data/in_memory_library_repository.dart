import 'package:uuid/uuid.dart';

import '../domain/folder.dart';
import '../domain/library_repository.dart';
import '../domain/notebook.dart';
import '../domain/paper_template.dart';

class InMemoryLibraryRepository implements LibraryRepository {
  InMemoryLibraryRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const Uuid _uuid = Uuid();

  final DateTime Function() _clock;
  final Map<String, Folder> _folders = {};
  final Map<String, Notebook> _notebooks = {};

  @override
  Future<List<Folder>> getFolders({String? parentId}) async {
    return _folders.values.where((f) => f.parentId == parentId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<List<Notebook>> getNotebooks({String? folderId}) async {
    return _notebooks.values.where((n) => n.folderId == folderId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<Folder> createFolder({required String name, String? parentId}) async {
    if (parentId != null) _requireFolder(parentId);
    final folder = Folder(
      id: _uuid.v4(),
      name: name,
      parentId: parentId,
      createdAt: _clock(),
    );
    _folders[folder.id] = folder;
    return folder;
  }

  @override
  Future<Notebook> createNotebook({
    required String title,
    required int coverColorValue,
    required PaperTemplate template,
    String? folderId,
  }) async {
    if (folderId != null) _requireFolder(folderId);
    final now = _clock();
    final notebook = Notebook(
      id: _uuid.v4(),
      title: title,
      folderId: folderId,
      coverColorValue: coverColorValue,
      template: template,
      createdAt: now,
      updatedAt: now,
    );
    _notebooks[notebook.id] = notebook;
    return notebook;
  }

  @override
  Future<void> renameFolder(String id, String name) async {
    _folders[id] = _requireFolder(id).copyWith(name: name);
  }

  @override
  Future<void> renameNotebook(String id, String title) async {
    _notebooks[id] = _requireNotebook(id)
        .copyWith(title: title, updatedAt: _clock());
  }

  @override
  Future<void> moveNotebook(String id, {String? toFolderId}) async {
    if (toFolderId != null) _requireFolder(toFolderId);
    _notebooks[id] = _requireNotebook(id)
        .movedTo(toFolderId, updatedAt: _clock());
  }

  @override
  Future<void> deleteNotebook(String id) async {
    _requireNotebook(id);
    _notebooks.remove(id);
  }

  @override
  Future<void> deleteFolder(String id) async {
    _requireFolder(id);

    final doomed = <String>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final folder in _folders.values) {
        final parent = folder.parentId;
        if (parent != null &&
            doomed.contains(parent) &&
            doomed.add(folder.id)) {
          grew = true;
        }
      }
    }

    _notebooks.removeWhere((_, n) => doomed.contains(n.folderId));
    _folders.removeWhere((folderId, _) => doomed.contains(folderId));
  }

  Folder _requireFolder(String id) =>
      _folders[id] ?? (throw StateError('Folder not found: $id'));

  Notebook _requireNotebook(String id) =>
      _notebooks[id] ?? (throw StateError('Notebook not found: $id'));

  @override
  Future<Folder?> getFolder(String id) async => _folders[id];

  @override
  Future<Notebook?> getNotebook(String id) async => _notebooks[id];

  @override
  Future<List<Folder>> getAllFolders() async =>
      _folders.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
