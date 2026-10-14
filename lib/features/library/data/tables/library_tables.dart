import 'package:drift/drift.dart';

import '../../domain/name_rules.dart';
import '../../domain/paper_template.dart';

/// Stores a [DateTime] as microseconds since the epoch: exact round-trip
/// and cheap to sort.
final class EpochMicrosConverter extends TypeConverter<DateTime, int> {
  const EpochMicrosConverter();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMicrosecondsSinceEpoch(fromDb);

  @override
  int toSql(DateTime value) => value.microsecondsSinceEpoch;
}

@DataClassName('FolderRow')
@TableIndex(name: 'idx_folders_parent_id', columns: {#parentId})
class FolderRows extends Table {
  @override
  String get tableName => 'folders';

  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: kMaxNameLength)();
  TextColumn get parentId => text()
      .nullable()
      .references(FolderRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer().map(const EpochMicrosConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('NotebookRow')
@TableIndex(name: 'idx_notebooks_folder_id', columns: {#folderId})
class NotebookRows extends Table {
  @override
  String get tableName => 'notebooks';

  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: kMaxNameLength)();
  TextColumn get folderId => text()
      .nullable()
      .references(FolderRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get coverColorValue => integer()();
  TextColumn get template => textEnum<PaperTemplate>()();
  IntColumn get createdAt => integer().map(const EpochMicrosConverter())();
  IntColumn get updatedAt => integer().map(const EpochMicrosConverter())();

  @override
  Set<Column> get primaryKey => {id};
}