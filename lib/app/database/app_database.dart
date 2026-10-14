import '../../features/library/domain/paper_template.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/library/data/tables/library_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [FolderRows, NotebookRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'quill_notes'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        beforeOpen: (details) async {
          // Required for ON DELETE CASCADE; SQLite has it off by default.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}