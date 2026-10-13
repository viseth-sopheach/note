import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/library/data/in_memory_library_repository.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';

void main() {
  late InMemoryLibraryRepository repo;

  setUp(() => repo = InMemoryLibraryRepository());

  test('creates a notebook at the root and lists it', () async {
    final notebook = await repo.createNotebook(
      title: 'Physics',
      coverColorValue: 0xFF3F5F8A,
      template: PaperTemplate.grid,
    );

    final root = await repo.getNotebooks();
    expect(root, [notebook]);
    expect(root.single.folderId, isNull);
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
    expect(await repo.getNotebooks(), [keeper]);
  });

  test('creating inside a missing folder throws', () async {
    expect(
      () => repo.createFolder(name: 'Orphan', parentId: 'nope'),
      throwsStateError,
    );
  });
}