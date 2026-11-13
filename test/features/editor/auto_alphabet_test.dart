import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/auto_alphabet_controller.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/application/page_texts_controller.dart';
import 'package:quill_notes/features/editor/application/tool_settings.dart';
import 'package:quill_notes/features/editor/data/in_memory_page_repository.dart';
import 'package:quill_notes/features/editor/domain/handwriting_language.dart';
import 'package:quill_notes/features/editor/domain/handwriting_recognizer.dart';
import 'package:quill_notes/features/editor/domain/stroke.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

class _Fake implements HandwritingRecognizer {
  int calls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<RecognizedText?> recognize(
    List<Stroke> strokes, {
    required HandwritingLanguage language,
  }) async {
    calls++;
    return const RecognizedText('hello', HandwritingLanguage.english);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late ToolSettings settings;
  late DrawingController c;
  late PageTextsController texts;
  late AutoAlphabetController auto;
  late _Fake fake;
  var n = 0;

  setUp(() {
    n = 0;
    fake = _Fake();
    settings = ToolSettings(tool: StrokeTool.autoPen);
    c = DrawingController(idGenerator: () => 'id${n++}', settings: settings);
    texts = PageTextsController(
      repository: InMemoryPageRepository(),
      notebookId: 'n',
      pageIndex: 0,
      pageSize: const Size(794, 1123),
      idGenerator: () => 'text',
    );
    auto = AutoAlphabetController(
      drawing: c,
      texts: texts,
      recognizer: fake,
      language: () => HandwritingLanguage.auto,
      measure: (t, s) => (width: t.length * s * 0.5, height: s * 1.25),
      idleDelay: const Duration(milliseconds: 40),
    );
  });

  tearDown(() async {
    auto.dispose();
    await texts.close();
    c.dispose();
    settings.dispose();
  });

  void write() {
    c.beginStroke(pointer: 1, x: 10, y: 10, pressure: 1, timeMs: 0);
    c.extendStroke(pointer: 1, x: 60, y: 30, pressure: 1, timeMs: 16);
    c.endStroke(pointer: 1, x: 120, y: 12, pressure: 1, timeMs: 32);
  }

  test('converts after the idle delay; undo restores the ink', () async {
    write();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(c.strokes, isEmpty);
    expect(texts.texts.single.text, 'hello');
    expect(texts.texts.single.handwriting, isTrue);

    c.undo();
    expect(c.strokes, hasLength(1));
    expect(texts.texts, isEmpty);

    c.redo();
    expect(c.strokes, isEmpty);
    expect(texts.texts, hasLength(1));
  });

  test('a stroke before the delay joins the same conversion', () async {
    write();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    write();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(fake.calls, 1);
    expect(c.strokes, isEmpty);
    expect(texts.texts, hasLength(1));
  });
}
