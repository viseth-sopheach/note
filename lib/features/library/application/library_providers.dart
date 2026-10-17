import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/database/app_database_provider.dart';
import '../data/drift_library_repository.dart';
import '../domain/folder.dart';
import '../domain/library_repository.dart';
import '../domain/notebook.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => DriftLibraryRepository(ref.watch(appDatabaseProvider)),
);

/// Folders inside the given parent (`null` = root).
final foldersProvider = FutureProvider.family<List<Folder>, String?>(
  (ref, parentId) =>
      ref.watch(libraryRepositoryProvider).getFolders(parentId: parentId),
);

/// Notebooks inside the given folder (`null` = root).
final notebooksProvider = FutureProvider.family<List<Notebook>, String?>(
  (ref, folderId) =>
      ref.watch(libraryRepositoryProvider).getNotebooks(folderId: folderId),
);

final folderProvider = FutureProvider.family<Folder?, String>(
  (ref, id) => ref.watch(libraryRepositoryProvider).getFolder(id),
);

final notebookProvider = FutureProvider.family<Notebook?, String>(
  (ref, id) => ref.watch(libraryRepositoryProvider).getNotebook(id),
);

/// Every folder, used by the "Move to" picker.
final allFoldersProvider = FutureProvider<List<Folder>>(
  (ref) => ref.watch(libraryRepositoryProvider).getAllFolders(),
);

final searchProvider = FutureProvider.autoDispose
    .family<({List<Folder> folders, List<Notebook> notebooks}), String>((
      ref,
      query,
    ) async {
      final repo = ref.watch(libraryRepositoryProvider);
      return (
        folders: await repo.searchFolders(query),
        notebooks: await repo.searchNotebooks(query),
      );
    });
