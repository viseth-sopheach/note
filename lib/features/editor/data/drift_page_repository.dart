import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../app/database/app_database.dart';
import '../../library/domain/paper_template.dart';
import '../domain/page_image.dart';
import '../domain/page_repository.dart';
import '../domain/page_text.dart';
import '../domain/stroke.dart';
import '../domain/stroke_codec.dart';

class DriftPageRepository implements PageRepository {
  DriftPageRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const Uuid _uuid = Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<PageRow?> _row(String notebookId, int pageIndex) {
    return (_db.select(_db.pageRows)..where(
          (t) =>
              t.notebookId.equals(notebookId) & t.pageIndex.equals(pageIndex),
        ))
        .getSingleOrNull();
  }

  @override
  Future<List<Stroke>> loadStrokes(
    String notebookId, {
    int pageIndex = 0,
  }) async {
    final row = await _row(notebookId, pageIndex);
    if (row == null || row.strokes.isEmpty) return const [];
    return StrokeCodec.decode(row.strokes);
  }

  @override
  Future<PaperTemplate?> loadTemplate(
    String notebookId, {
    int pageIndex = 0,
  }) async {
    final row = await _row(notebookId, pageIndex);
    return row?.template;
  }

  @override
  Future<String?> loadImagePath(String notebookId, {int pageIndex = 0}) async =>
      (await _row(notebookId, pageIndex))?.imagePath;

  @override
  Future<List<PageImage>> loadImages(
    String notebookId, {
    int pageIndex = 0,
  }) async => PageImage.decodeList((await _row(notebookId, pageIndex))?.images);

  @override
  Future<void> saveImages(
    String notebookId,
    List<PageImage> images, {
    int pageIndex = 0,
  }) {
    final json = images.isEmpty ? null : PageImage.encodeList(images);
    final now = _clock();

    return _db.transaction(() async {
      final updated =
          await (_db.update(_db.pageRows)..where(
                (t) =>
                    t.notebookId.equals(notebookId) &
                    t.pageIndex.equals(pageIndex),
              ))
              .write(
                PageRowsCompanion(images: Value(json), updatedAt: Value(now)),
              );
      if (updated > 0 || json == null) return;

      await _db
          .into(_db.pageRows)
          .insert(
            PageRowsCompanion.insert(
              id: _uuid.v4(),
              notebookId: notebookId,
              pageIndex: pageIndex,
              strokes: StrokeCodec.encode(const []),
              updatedAt: now,
              images: Value(json),
            ),
          );
    });
  }

  @override
  Future<List<PageText>> loadTexts(
    String notebookId, {
    int pageIndex = 0,
  }) async => PageText.decodeList((await _row(notebookId, pageIndex))?.texts);

  @override
  Future<void> saveTexts(
    String notebookId,
    List<PageText> texts, {
    int pageIndex = 0,
  }) {
    final json = texts.isEmpty ? null : PageText.encodeList(texts);
    final now = _clock();

    return _db.transaction(() async {
      final updated =
          await (_db.update(_db.pageRows)..where(
                (t) =>
                    t.notebookId.equals(notebookId) &
                    t.pageIndex.equals(pageIndex),
              ))
              .write(
                PageRowsCompanion(texts: Value(json), updatedAt: Value(now)),
              );
      if (updated > 0 || json == null) return;

      await _db
          .into(_db.pageRows)
          .insert(
            PageRowsCompanion.insert(
              id: _uuid.v4(),
              notebookId: notebookId,
              pageIndex: pageIndex,
              strokes: StrokeCodec.encode(const []),
              updatedAt: now,
              texts: Value(json),
            ),
          );
    });
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
      final updated =
          await (_db.update(_db.pageRows)..where(
                (t) =>
                    t.notebookId.equals(notebookId) &
                    t.pageIndex.equals(pageIndex),
              ))
              .write(
                PageRowsCompanion(strokes: Value(blob), updatedAt: Value(now)),
              );
      if (updated > 0) return;

      await _db
          .into(_db.pageRows)
          .insert(
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
    final row =
        await (_db.selectOnly(_db.pageRows)
              ..addColumns([maxIndex])
              ..where(_db.pageRows.notebookId.equals(notebookId)))
            .getSingle();
    final max = row.read(maxIndex);
    return max == null ? 0 : max + 1;
  }

  @override
  Future<void> insertPage(
    String notebookId, {
    required int pageIndex,
    required PaperTemplate template,
    List<Stroke> strokes = const [],
    String? imagePath,
    List<PageImage> images = const [],
    List<PageText> texts = const [],
  }) async {
    if (pageIndex < 0) {
      throw ArgumentError.value(pageIndex, 'pageIndex', 'Must not be negative');
    }
    // Encoded before the first await so later edits cannot change the data.
    final blob = StrokeCodec.encode(strokes);
    final now = _clock();

    await _db.transaction(() async {
      await _shiftPages(notebookId, from: pageIndex, delta: 1);
      await _db
          .into(_db.pageRows)
          .insert(
            PageRowsCompanion.insert(
              id: _uuid.v4(),
              notebookId: notebookId,
              pageIndex: pageIndex,
              strokes: blob,
              updatedAt: now,
              template: Value(template),
              imagePath: Value(imagePath),
              images: Value(
                images.isEmpty ? null : PageImage.encodeList(images),
              ),
              texts: Value(texts.isEmpty ? null : PageText.encodeList(texts)),
            ),
          );
    });
  }

  @override
  Future<void> deletePage(String notebookId, int pageIndex) {
    return _db.transaction(() async {
      await (_db.delete(_db.pageRows)..where(
            (t) =>
                t.notebookId.equals(notebookId) & t.pageIndex.equals(pageIndex),
          ))
          .go();
      await _shiftPages(notebookId, from: pageIndex + 1, delta: -1);
    });
  }

  /// Moves every page with index >= [from] by [delta].
  ///
  /// Two steps through negative indexes, because the (notebook_id,
  /// page_index) unique key is checked row by row.
  Future<void> _shiftPages(
    String notebookId, {
    required int from,
    required int delta,
  }) async {
    await _db.customUpdate(
      'UPDATE pages SET page_index = -page_index - 1 '
      'WHERE notebook_id = ? AND page_index >= ?',
      variables: [Variable.withString(notebookId), Variable.withInt(from)],
      updates: {_db.pageRows},
    );
    await _db.customUpdate(
      'UPDATE pages SET page_index = -page_index - 1 + ? '
      'WHERE notebook_id = ? AND page_index < 0',
      variables: [Variable.withInt(delta), Variable.withString(notebookId)],
      updates: {_db.pageRows},
    );
  }
}
