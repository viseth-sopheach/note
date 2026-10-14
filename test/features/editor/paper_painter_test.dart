import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/presentation/paper/paper_painter.dart';
import 'package:quill_notes/features/editor/presentation/paper/paper_view.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';

void main() {
  test('repaints only when the template changes', () {
    const lined = PaperPainter(PaperTemplate.lined);
    expect(lined.shouldRepaint(const PaperPainter(PaperTemplate.lined)), isFalse);
    expect(lined.shouldRepaint(const PaperPainter(PaperTemplate.grid)), isTrue);
  });

  testWidgets('every template renders at page size', (tester) async {
    for (final template in PaperTemplate.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(child: PaperView(template: template)),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PaperView)), kPageSize);
    }
  });
}