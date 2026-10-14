import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/app/database/app_database.dart';
import 'package:quill_notes/features/editor/data/drift_page_repository.dart';
import 'package:quill_notes/features/editor/data/in_memory_page_repository.dart';
import 'package:quill_notes/features/editor/domain/page_repository.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';
import 'package:quill_notes/features/library/data/drift_library_repository.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';

typedef _Fixture = ({PageRepository pages, String notebookId});

void main() {
  _run(
    'InMemoryPageRepository',
    () async => (pages: InMemoryPageRepository(), notebookId: 'n'),
  );

  _run('DriftPageRepository', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final notebook = await DriftLibraryRepository(db).createNotebook(
      title: 'T',
      coverColorValue: 0xFF000000,
      template: PaperTemplate.blank,
    );
    return (pages: DriftPageRepository(db), notebookId: notebook.id);
  });
}

void _run(String name, Future<_Fixture> Function() create) {
  group('$name page structure', () {
    late PageRepository pages;
    late String id;

    setUp(() async {
      final fixture = await create();
      pages = fixture.pages;
      id = fixture.notebookId;
    });

    Stroke stroke(String strokeId) => Stroke(
          id: strokeId,
          tool: StrokeTool.pen,
          colorValue: 0xFF000000,
          width: 2,
          points: const [StrokePoint(x: 1, y: 1)],
        );

    Future<void> seed(List<String> ids) async {
      for (var i = 0; i < ids.length; i++) {
        await pages.saveStrokes(id, [stroke(ids[i])], pageIndex: i);
      }
    }

    Future<List<String>> order() async {
      final count = await pages.pageCount(id);
      final result = <String>[];
      for (var i = 0; i < count; i++) {
        final strokes = await pages.loadStrokes(id, pageIndex: i);
        result.add(strokes.isEmpty ? '-' : strokes.single.id);
      }
      return result;
    }

    test('inserting in the middle moves later pages down', () async {
      await seed(['a', 'b', 'c']);

      await pages.insertPage(
        id,
        pageIndex: 1,
        template: PaperTemplate.grid,
        strokes: [stroke('x')],
      );

      expect(await order(), ['a', 'x', 'b', 'c']);
      expect(await pages.loadTemplate(id, pageIndex: 1), PaperTemplate.grid);
      expect(await pages.loadTemplate(id, pageIndex: 2), isNull);
    });

    test('inserting at the end appends', () async {
      await seed(['a', 'b']);

      await pages.insertPage(id, pageIndex: 2, template: PaperTemplate.dotted);

      expect(await order(), ['a', 'b', '-']);
      expect(await pages.loadTemplate(id, pageIndex: 2), PaperTemplate.dotted);
    });

    test('deleting a middle page moves later pages up', () async {
      await seed(['a', 'b', 'c']);

      await pages.deletePage(id, 1);

      expect(await order(), ['a', 'c']);
    });

    test('deleting the first page works', () async {
      await seed(['a', 'b', 'c']);

      await pages.deletePage(id, 0);

      expect(await order(), ['b', 'c']);
    });

    test('saving strokes keeps the page template', () async {
      await pages.insertPage(id, pageIndex: 0, template: PaperTemplate.lined);

      await pages.saveStrokes(id, [stroke('a')], pageIndex: 0);

      expect(await pages.loadTemplate(id), PaperTemplate.lined);
      expect(await order(), ['a']);
    });

    test('a negative index is rejected', () async {
      expect(
        () => pages.insertPage(id, pageIndex: -1, template: PaperTemplate.blank),
        throwsArgumentError,
      );
    });
  });
}