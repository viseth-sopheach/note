import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.steps.dart';

import '../../features/editor/data/tables/editor_tables.dart';
import '../../features/library/data/tables/library_tables.dart';
import '../../features/library/domain/paper_template.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [FolderRows, NotebookRows, PageRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'quill_notes'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: stepByStep(
      from1To2: (migrator, schema) async {
        await migrator.createTable(schema.pages);
      },
      from2To3: (migrator, schema) async {
        await migrator.addColumn(schema.pages, schema.pages.template);
      },
      from3To4: (migrator, schema) async {
        await migrator.addColumn(schema.notebooks, schema.notebooks.pdfPath);
      },
      from4To5: (migrator, schema) async {
        await migrator.addColumn(schema.pages, schema.pages.imagePath);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
