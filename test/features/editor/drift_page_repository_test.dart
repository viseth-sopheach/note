import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/app/database/app_database.dart';
import 'package:quill_notes/features/editor/data/drift_page_repository.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';
import 'package:quill_notes/features/library/data/drift_library_repository.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';

void main() {
  late AppDatabase db;
  late DriftLibraryRepository library;
  late DriftPageRepository pages;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    library = DriftLibraryRepository(db);
    pages = DriftPageRepository(db);
  });

  tearDown(() => db.close());

  Stroke stroke(String id) => Stroke(
    id: id,
    tool: StrokeTool.pen,
    colorValue: 0xFF1B1B1F,
    width: 2,
    points: const [
      StrokePoint(x: 1.5, y: 2.5, pressure: 0.5, timestampMs: 0),
      StrokePoint(x: 10, y: 20, pressure: 1, timestampMs: 16),
    ],
  );

  Future<String> newNotebookId() async => (await library.createNotebook(
    title: 'Test',
    coverColorValue: 0xFF000000,
    template: PaperTemplate.blank,
  )).id;

  test('a new notebook has no strokes', () async {
    final id = await newNotebookId();
    expect(await pages.loadStrokes(id), isEmpty);
  });

  test('saved strokes load back', () async {
    final id = await newNotebookId();

    await pages.saveStrokes(id, [stroke('a'), stroke('b')]);

    expect(await pages.loadStrokes(id), [stroke('a'), stroke('b')]);
  });

  test('saving again replaces the strokes and keeps one row', () async {
    final id = await newNotebookId();

    await pages.saveStrokes(id, [stroke('a')]);
    await pages.saveStrokes(id, [stroke('b')]);

    expect(await pages.loadStrokes(id), [stroke('b')]);
    expect(await db.select(db.pageRows).get(), hasLength(1));
  });

  test('deleting a notebook deletes its page', () async {
    final id = await newNotebookId();
    await pages.saveStrokes(id, [stroke('a')]);

    await library.deleteNotebook(id);

    expect(await db.select(db.pageRows).get(), isEmpty);
  });

  test('strokes stay with their own notebook', () async {
    final first = await newNotebookId();
    final second = await newNotebookId();

    await pages.saveStrokes(first, [stroke('a')]);

    expect(await pages.loadStrokes(second), isEmpty);
  });
}
