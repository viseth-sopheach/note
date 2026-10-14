import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/autosave_controller.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/data/in_memory_page_repository.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_point.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  late DrawingController controller;
  late InMemoryPageRepository repo;

  setUp(() {
    controller = DrawingController(idGenerator: () => 'id');
    repo = InMemoryPageRepository();
  });

  void drawOneStroke() {
    controller.beginStroke(pointer: 1, x: 0, y: 0, pressure: 1, timeMs: 0);
    controller.endStroke(pointer: 1, x: 10, y: 0, pressure: 1, timeMs: 16);
  }

  AutosaveController makeAutosave(Duration delay) => AutosaveController(
        controller: controller,
        repository: repo,
        notebookId: 'n1',
        delay: delay,
      );

  test('saves shortly after a stroke is finished', () async {
    final autosave = makeAutosave(const Duration(milliseconds: 20));
    addTearDown(() async {
      await autosave.dispose();
      controller.dispose();
    });

    drawOneStroke();
    expect(repo.saveCount, 0);

    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(repo.saveCount, 1);
    expect(await repo.loadStrokes('n1'), hasLength(1));
  });

  test('flush saves immediately', () async {
    final autosave = makeAutosave(const Duration(seconds: 30));
    addTearDown(() async {
      await autosave.dispose();
      controller.dispose();
    });

    drawOneStroke();
    await autosave.flush();

    expect(repo.saveCount, 1);
  });

  test('flush does nothing when nothing changed', () async {
    final autosave = makeAutosave(const Duration(seconds: 30));
    addTearDown(() async {
      await autosave.dispose();
      controller.dispose();
    });

    await autosave.flush();

    expect(repo.saveCount, 0);
  });

  test('loading strokes does not trigger a save', () async {
    controller.replaceStrokes([
      Stroke(
        id: 'old',
        tool: StrokeTool.pen,
        colorValue: 0xFF000000,
        width: 2,
        points: const [StrokePoint(x: 1, y: 1)],
      ),
    ]);
    final autosave = makeAutosave(const Duration(milliseconds: 10));
    addTearDown(() async {
      await autosave.dispose();
      controller.dispose();
    });

    await autosave.flush();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(repo.saveCount, 0);
  });

  test('dispose saves pending changes', () async {
    final autosave = makeAutosave(const Duration(seconds: 30));
    addTearDown(controller.dispose);

    drawOneStroke();
    await autosave.dispose();

    expect(await repo.loadStrokes('n1'), hasLength(1));
  });
}