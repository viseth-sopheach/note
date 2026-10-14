import 'package:drift/drift.dart';

import '../../../library/data/tables/library_tables.dart';
import '../../../library/domain/paper_template.dart';

@DataClassName('PageRow')
class PageRows extends Table {
  @override
  String get tableName => 'pages';

  TextColumn get id => text()();
  TextColumn get notebookId => text()
      .references(NotebookRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageIndex => integer()();

  /// Binary stroke data, see StrokeCodec.
  BlobColumn get strokes => blob()();

  /// Paper template of this page. Null means "use the notebook's template".
  TextColumn get template => textEnum<PaperTemplate>().nullable()();
  IntColumn get updatedAt => integer().map(const EpochMicrosConverter())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {notebookId, pageIndex},
      ];
}