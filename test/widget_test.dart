import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/app/app.dart';
import 'package:quill_notes/features/library/application/library_providers.dart';
import 'package:quill_notes/features/library/data/in_memory_library_repository.dart';

void main() {
  testWidgets('app starts on the library screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider
              .overrideWithValue(InMemoryLibraryRepository()),
        ],
        child: const NoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('No notebooks yet'), findsOneWidget);
  });
}
