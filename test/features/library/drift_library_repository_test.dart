import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/app/database/app_database.dart';
import 'package:quill_notes/features/library/data/drift_library_repository.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';

import 'library_repository_contract.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  runLibraryRepositoryContract('DriftLibraryRepository', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return DriftLibraryRepository(db);
  });

  group('DriftLibraryRepository specifics', () {
    late AppDatabase db;
    late DriftLibraryRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftLibraryRepository(db);
    });

    tearDown(() => db.close());

    test('rejects blank and overlong names', () async {
      expect(() => repo.createFolder(name: '   '), throwsArgumentError);
      expect(() => repo.createFolder(name: 'x' * 81), throwsArgumentError);
      expect(
        () => repo.createNotebook(
          title: '',
          coverColorValue: 0xFF000000,
          template: PaperTemplate.blank,
        ),
        throwsArgumentError,
      );
    });

    test('trims names before saving', () async {
      final folder = await repo.createFolder(name: '   Work  ');
      expect(folder.name, 'Work');
      expect((await repo.getFolder(folder.id))?.name, 'Work');
    });

    test('data survives reopening the database file', () async {
      final dir = Directory.systemTemp.createTempSync('quill_notes_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/library.db');

      var reopened = AppDatabase(NativeDatabase(file));
      final notebook = await DriftLibraryRepository(reopened).createNotebook(
        title: 'Kept',
        coverColorValue: 0xFF3F5F8A,
        template: PaperTemplate.dotted,
      );
      await reopened.close();

      reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);

      expect(await DriftLibraryRepository(reopened).getNotebooks(), [notebook]);
    });
  });
}
