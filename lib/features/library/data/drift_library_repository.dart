import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../app/database/app_database.dart';
import '../domain/folder.dart';
import '../domain/library_repository.dart';
import '../domain/name_rules.dart';
import '../domain/notebook.dart';
import '../domain/paper_template.dart';

class DriftLibraryRepository implements LibraryRepository {
  DriftLibraryRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const Uuid _uuid = Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<List<Folder>> getFolders({String? parentId}) async {
    final query = _db.select(_db.folderRows)
      ..where(
        (t) => parentId == null
            ? t.parentId.isNull()
            : t.parentId.equals(parentId),
      )
      ..orderBy([(t) => _byName(t.name)]);
    return [for (final row in await query.get()) row.toDomain()];
  }

  @override
  Future<List<Folder>> getAllFolders() async {
    final query = _db.select(_db.folderRows)..orderBy([(t) => _byName(t.name)]);
    return [for (final row in await query.get()) row.toDomain()];
  }

  @override
  Future<Folder?> getFolder(String id) async {
    final row = await (_db.select(
      _db.folderRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<Notebook>> getNotebooks({String? folderId}) async {
    final query = _db.select(_db.notebookRows)
      ..where(
        (t) => folderId == null
            ? t.folderId.isNull()
            : t.folderId.equals(folderId),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    return [for (final row in await query.get()) row.toDomain()];
  }

  @override
  Future<Notebook?> getNotebook(String id) async {
    final row = await (_db.select(
      _db.notebookRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<Folder>> searchFolders(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final stmt = _db.select(_db.folderRows)
      ..where((t) => t.name.like('%$q%'))
      ..orderBy([(t) => _byName(t.name)]);
    return [for (final r in await stmt.get()) r.toDomain()];
  }

  @override
  Future<List<Notebook>> searchNotebooks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final stmt = _db.select(_db.notebookRows)
      ..where((t) => t.title.like('%$q%'))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return [for (final r in await stmt.get()) r.toDomain()];
  }

  @override
  Future<Folder> createFolder({required String name, String? parentId}) async {
    final cleanName = _validated(name, 'name');
    return _db.transaction(() async {
      if (parentId != null) await _requireFolder(parentId);
      final folder = Folder(
        id: _uuid.v4(),
        name: cleanName,
        parentId: parentId,
        createdAt: _clock(),
      );
      await _db
          .into(_db.folderRows)
          .insert(
            FolderRowsCompanion.insert(
              id: folder.id,
              name: folder.name,
              createdAt: folder.createdAt,
              parentId: Value(parentId),
            ),
          );
      return folder;
    });
  }

  @override
  Future<Notebook> createNotebook({
    required String title,
    required int coverColorValue,
    required PaperTemplate template,
    String? folderId,
    String? pdfPath,
  }) async {
    final cleanTitle = _validated(title, 'title');
    return _db.transaction(() async {
      if (folderId != null) await _requireFolder(folderId);
      final now = _clock();
      final notebook = Notebook(
        id: _uuid.v4(),
        title: cleanTitle,
        folderId: folderId,
        coverColorValue: coverColorValue,
        template: template,
        pdfPath: pdfPath,
        createdAt: now,
        updatedAt: now,
      );
      await _db
          .into(_db.notebookRows)
          .insert(
            NotebookRowsCompanion.insert(
              id: notebook.id,
              title: notebook.title,
              coverColorValue: notebook.coverColorValue,
              template: notebook.template,
              createdAt: notebook.createdAt,
              updatedAt: notebook.updatedAt,
              folderId: Value(folderId),
              pdfPath: Value(pdfPath),
            ),
          );
      return notebook;
    });
  }

  @override
  Future<void> renameFolder(String id, String name) async {
    final cleanName = _validated(name, 'name');
    final updated =
        await (_db.update(_db.folderRows)..where((t) => t.id.equals(id))).write(
          FolderRowsCompanion(name: Value(cleanName)),
        );
    if (updated == 0) throw StateError('Folder not found: $id');
  }

  @override
  Future<void> renameNotebook(String id, String title) async {
    final cleanTitle = _validated(title, 'title');
    final updated =
        await (_db.update(
          _db.notebookRows,
        )..where((t) => t.id.equals(id))).write(
          NotebookRowsCompanion(
            title: Value(cleanTitle),
            updatedAt: Value(_clock()),
          ),
        );
    if (updated == 0) throw StateError('Notebook not found: $id');
  }

  @override
  Future<void> moveNotebook(String id, {String? toFolderId}) {
    return _db.transaction(() async {
      if (toFolderId != null) await _requireFolder(toFolderId);
      final updated =
          await (_db.update(
            _db.notebookRows,
          )..where((t) => t.id.equals(id))).write(
            NotebookRowsCompanion(
              folderId: Value(toFolderId),
              updatedAt: Value(_clock()),
            ),
          );
      if (updated == 0) throw StateError('Notebook not found: $id');
    });
  }

  @override
  Future<void> deleteNotebook(String id) async {
    final deleted = await (_db.delete(
      _db.notebookRows,
    )..where((t) => t.id.equals(id))).go();
    if (deleted == 0) throw StateError('Notebook not found: $id');
  }

  /// Subfolders and notebooks are removed by ON DELETE CASCADE.
  @override
  Future<void> deleteFolder(String id) async {
    final deleted = await (_db.delete(
      _db.folderRows,
    )..where((t) => t.id.equals(id))).go();
    if (deleted == 0) throw StateError('Folder not found: $id');
  }

  Future<void> _requireFolder(String id) async {
    final exists =
        await (_db.selectOnly(_db.folderRows)
              ..addColumns([_db.folderRows.id])
              ..where(_db.folderRows.id.equals(id)))
            .getSingleOrNull();
    if (exists == null) throw StateError('Folder not found: $id');
  }

  static String _validated(String value, String field) {
    final error = validateName(value);
    if (error != null) throw ArgumentError.value(value, field, error);
    return value.trim();
  }

  static OrderingTerm _byName(Expression<String> name) =>
      OrderingTerm.asc(name.collate(Collate.noCase));
}

extension on FolderRow {
  Folder toDomain() =>
      Folder(id: id, name: name, parentId: parentId, createdAt: createdAt);
}

extension on NotebookRow {
  Notebook toDomain() => Notebook(
    id: id,
    title: title,
    folderId: folderId,
    coverColorValue: coverColorValue,
    template: template,
    pdfPath: pdfPath,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
