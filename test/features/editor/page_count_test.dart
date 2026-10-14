import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/app/database/app_database.dart';
import 'package:quill_notes/features/editor/data/drift_page_repository.dart';
import 'package:quill_notes/features/editor/data/in_memory_page_repository.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';
import 'package:quill_notes/features/library/data/drift_library_repository.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';

void main() {
  Stroke stroke(String id) => Stroke(
        id: id,
        tool: StrokeTool.pen,
        colorValue: 0xFF000000,
        width: 2,
        points: const [StrokePoint(x: 1, y: 1)],
      );

  group('InMemoryPageRepository pages', () {
    late InMemoryPageRepository repo;

    setUp(() => repo = InMemoryPageRepository());

    test('count is 0, then highest saved index + 1', () async {
      expect(await repo.pageCount('n'), 0);
      await repo.saveStrokes('n', const [], pageIndex: 0);
      expect(await repo.pageCount('n'), 1);
      await repo.saveStrokes('n', const [], pageIndex: 2);
      expect(await repo.pageCount('n'), 3);
      expect(await repo.pageCount('other'), 0);
    });

    test('pages keep their own strokes', () async {
      await repo.saveStrokes('n', [stroke('a')], pageIndex: 0);
      await repo.saveStrokes('n', [stroke('b')], pageIndex: 1);

      expect((await repo.loadStrokes('n', pageIndex: 0)).single.id, 'a');
      expect((await repo.loadStrokes('n', pageIndex: 1)).single.id, 'b');
    });
  });

  group('DriftPageRepository pages', () {
    late AppDatabase db;
    late DriftLibraryRepository library;
    late DriftPageRepository pages;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      library = DriftLibraryRepository(db);
      pages = DriftPageRepository(db);
    });

    tearDown(() => db.close());

    Future<String> newId() async => (await library.createNotebook(
          title: 'T',
          coverColorValue: 0xFF000000,
          template: PaperTemplate.blank,
        ))
            .id;

    test('count is 0, then highest saved index + 1', () async {
      final id = await newId();
      final other = await newId();

      expect(await pages.pageCount(id), 0);
      await pages.saveStrokes(id, const [], pageIndex: 0);
      expect(await pages.pageCount(id), 1);
      await pages.saveStrokes(id, const [], pageIndex: 2);
      expect(await pages.pageCount(id), 3);
      expect(await pages.pageCount(other), 0);
    });

    test('pages keep their own strokes', () async {
      final id = await newId();
      await pages.saveStrokes(id, [stroke('a')], pageIndex: 0);
      await pages.saveStrokes(id, [stroke('b')], pageIndex: 1);

      expect((await pages.loadStrokes(id, pageIndex: 0)).single.id, 'a');
      expect((await pages.loadStrokes(id, pageIndex: 1)).single.id, 'b');
    });
  });
}