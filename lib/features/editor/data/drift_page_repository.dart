import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../app/database/app_database.dart';
import '../domain/page_repository.dart';
import '../domain/stroke.dart';
import '../domain/stroke_codec.dart';

class DriftPageRepository implements PageRepository {
  DriftPageRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const Uuid _uuid = Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<List<Stroke>> loadStrokes(
    String notebookId, {
    int pageIndex = 0,
  }) async {
    final row = await (_db.select(_db.pageRows)
          ..where(
            (t) =>
                t.notebookId.equals(notebookId) & t.pageIndex.equals(pageIndex),
          ))
        .getSingleOrNull();
    if (row == null || row.strokes.isEmpty) return const [];
    return StrokeCodec.decode(row.strokes);
  }

  @override
  Future<void> saveStrokes(
    String notebookId,
    List<Stroke> strokes, {
    int pageIndex = 0,
  }) {
    // Encoded before the first await so later edits cannot change the data.
    final blob = StrokeCodec.encode(strokes);
    final now = _clock();

    return _db.transaction(() async {
      final updated = await (_db.update(_db.pageRows)
            ..where(
              (t) =>
                  t.notebookId.equals(notebookId) &
                  t.pageIndex.equals(pageIndex),
            ))
          .write(
        PageRowsCompanion(strokes: Value(blob), updatedAt: Value(now)),
      );
      if (updated > 0) return;

      await _db.into(_db.pageRows).insert(
            PageRowsCompanion.insert(
              id: _uuid.v4(),
              notebookId: notebookId,
              pageIndex: pageIndex,
              strokes: blob,
              updatedAt: now,
            ),
          );
    });
  }

  @override
  Future<int> pageCount(String notebookId) async {
    final maxIndex = _db.pageRows.pageIndex.max();
    final row = await (_db.selectOnly(_db.pageRows)
          ..addColumns([maxIndex])
          ..where(_db.pageRows.notebookId.equals(notebookId)))
        .getSingle();
    final max = row.read(maxIndex);
    return max == null ? 0 : max + 1;
  }
}