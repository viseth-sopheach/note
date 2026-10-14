import 'package:quill_notes/features/library/data/in_memory_library_repository.dart';

import 'library_repository_contract.dart';

void main() {
  runLibraryRepositoryContract(
    'InMemoryLibraryRepository',
    () async => InMemoryLibraryRepository(),
  );
}