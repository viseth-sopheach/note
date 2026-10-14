import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/library/application/library_actions.dart';
import 'package:quill_notes/features/library/application/library_providers.dart';
import 'package:quill_notes/features/library/data/in_memory_library_repository.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';

void main() {
  late InMemoryLibraryRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = InMemoryLibraryRepository();
    container = ProviderContainer(
      overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  LibraryActions actions() => container.read(libraryActionsProvider);

  test('renameFolder trims and refreshes cached lists', () async {
    final folder = await actions().createFolder(name: 'School');
    expect((await container.read(foldersProvider(null).future)).single.name,
        'School');

    await actions().renameFolder(folder.id, '  Work  ');

    final folders = await container.read(foldersProvider(null).future);
    expect(folders.single.name, 'Work');
  });

  test('moveNotebook moves to a folder and back to root', () async {
    final folder = await actions().createFolder(name: 'School');
    final notebook = await actions().createNotebook(
      title: 'Math',
      coverColorValue: 0xFF000000,
      template: PaperTemplate.blank,
    );

    await actions().moveNotebook(notebook.id, toFolderId: folder.id);
    expect(await container.read(notebooksProvider(null).future), isEmpty);
    expect(await container.read(notebooksProvider(folder.id).future),
        hasLength(1));

    await actions().moveNotebook(notebook.id);
    expect(await container.read(notebooksProvider(null).future), hasLength(1));
  });

  test('deleteFolder removes its notebooks', () async {
    final folder = await actions().createFolder(name: 'Temp');
    await actions().createNotebook(
      title: 'Inside',
      coverColorValue: 0xFF000000,
      template: PaperTemplate.lined,
      folderId: folder.id,
    );

    await actions().deleteFolder(folder.id);

    expect(await container.read(foldersProvider(null).future), isEmpty);
    expect(await repo.getNotebooks(folderId: folder.id), isEmpty);
    expect(await container.read(folderProvider(folder.id).future), isNull);
  });

  test('deleteNotebook on a missing id throws', () async {
    expect(() => actions().deleteNotebook('nope'), throwsStateError);
  });
}