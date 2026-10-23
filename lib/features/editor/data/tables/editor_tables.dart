import 'package:drift/drift.dart';

import '../../../library/data/tables/library_tables.dart';
import '../../../library/domain/paper_template.dart';

@DataClassName('PageRow')
class PageRows extends Table {
  @override
  String get tableName => 'pages';

  TextColumn get id => text()();
  TextColumn get notebookId =>
      text().references(NotebookRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageIndex => integer()();

  /// Binary stroke data, see StrokeCodec.
  BlobColumn get strokes => blob()();

  /// Paper template of this page. Null means "use the notebook's template".
  TextColumn get template => textEnum<PaperTemplate>().nullable()();

  /// Image shown as the page background, or null.
  TextColumn get imagePath => text().nullable()();

  IntColumn get updatedAt => integer().map(const EpochMicrosConverter())();

  /// JSON list of images placed on the page (see PageImage), or null.
  TextColumn get images => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {notebookId, pageIndex},
  ];
}