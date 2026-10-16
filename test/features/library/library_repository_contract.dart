import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/library/domain/library_repository.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';

/// Behavior every [LibraryRepository] implementation must share.
void runLibraryRepositoryContract(
  String name,
  Future<LibraryRepository> Function() create,
) {
  group(name, () {
    late LibraryRepository repo;

    setUp(() async => repo = await create());

    test('creates a notebook at the root and lists it', () async {
      final notebook = await repo.createNotebook(
        title: 'Physics',
        coverColorValue: 0xFF3F5F8A,
        template: PaperTemplate.grid,
      );

      final root = await repo.getNotebooks();
      expect(root, [notebook]);
      expect(root.single.folderId, isNull);
      expect(await repo.getNotebook(notebook.id), notebook);
    });

    test('notebooks only appear in their own folder', () async {
      final folder = await repo.createFolder(name: 'School');
      await repo.createNotebook(
        title: 'Math',
        coverColorValue: 0xFF000000,
        template: PaperTemplate.lined,
        folderId: folder.id,
      );

      expect(await repo.getNotebooks(), isEmpty);
      expect(await repo.getNotebooks(folderId: folder.id), hasLength(1));
    });

    test('folders are sorted by name, ignoring case', () async {
      await repo.createFolder(name: 'banana');
      await repo.createFolder(name: 'Apple');
      await repo.createFolder(name: 'cherry');

      final names = (await repo.getFolders()).map((f) => f.name);
      expect(names, ['Apple', 'banana', 'cherry']);
      expect((await repo.getAllFolders()).map((f) => f.name), names);
    });

    test('moving a notebook to the root works', () async {
      final folder = await repo.createFolder(name: 'School');
      final notebook = await repo.createNotebook(
        title: 'Math',
        coverColorValue: 0xFF000000,
        template: PaperTemplate.lined,
        folderId: folder.id,
      );

      await repo.moveNotebook(notebook.id);

      expect(await repo.getNotebooks(), hasLength(1));
      expect(await repo.getNotebooks(folderId: folder.id), isEmpty);
    });

    test('renaming changes the title', () async {
      final notebook = await repo.createNotebook(
        title: 'Old',
        coverColorValue: 0xFF000000,
        template: PaperTemplate.blank,
      );
      final folder = await repo.createFolder(name: 'Old');

      await repo.renameNotebook(notebook.id, 'New');
      await repo.renameFolder(folder.id, 'Newer');

      expect((await repo.getNotebook(notebook.id))?.title, 'New');
      expect((await repo.getFolder(folder.id))?.name, 'Newer');
    });

    test('deleting a notebook removes it', () async {
      final notebook = await repo.createNotebook(
        title: 'Temp',
        coverColorValue: 0xFF000000,
        template: PaperTemplate.blank,
      );

      await repo.deleteNotebook(notebook.id);

      expect(await repo.getNotebook(notebook.id), isNull);
    });

    test('deleting a folder removes subfolders and their notebooks', () async {
      final parent = await repo.createFolder(name: 'Parent');
      final child = await repo.createFolder(name: 'Child', parentId: parent.id);
      await repo.createNotebook(
        title: 'Deep',
        coverColorValue: 0xFF000000,
        template: PaperTemplate.blank,
        folderId: child.id,
      );
      final keeper = await repo.createNotebook(
        title: 'Keeper',
        coverColorValue: 0xFF000000,
        template: PaperTemplate.blank,
      );

      await repo.deleteFolder(parent.id);

      expect(await repo.getFolders(), isEmpty);
      expect(await repo.getFolders(parentId: parent.id), isEmpty);
      expect(await repo.getNotebooks(folderId: child.id), isEmpty);
      expect(await repo.getNotebooks(), [keeper]);
    });

    test('creating inside a missing folder throws', () async {
      expect(
        () => repo.createFolder(name: 'Orphan', parentId: 'nope'),
        throwsStateError,
      );
      expect(
        () => repo.createNotebook(
          title: 'Orphan',
          coverColorValue: 0xFF000000,
          template: PaperTemplate.blank,
          folderId: 'nope',
        ),
        throwsStateError,
      );
    });

    test('operations on missing ids throw', () async {
      expect(() => repo.renameFolder('nope', 'x'), throwsStateError);
      expect(() => repo.renameNotebook('nope', 'x'), throwsStateError);
      expect(() => repo.moveNotebook('nope'), throwsStateError);
      expect(() => repo.deleteNotebook('nope'), throwsStateError);
      expect(() => repo.deleteFolder('nope'), throwsStateError);
    });
    test('stores the pdf path', () async {
      final notebook = await repo.createNotebook(
        title: 'Doc',
        coverColorValue: 0xFF000000,
        template: PaperTemplate.blank,
        pdfPath: '/data/pdfs/a.pdf',
      );
      expect((await repo.getNotebook(notebook.id))?.pdfPath, '/data/pdfs/a.pdf');
    });
  });
}