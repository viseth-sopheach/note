import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';
import 'package:quill_notes/features/library/presentation/cover_palette.dart';
import 'package:quill_notes/features/library/presentation/dialogs/new_notebook_dialog.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    void Function(NewNotebookResult?) onClosed,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async =>
                    onClosed(await NewNotebookDialog.show(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('returns defaults when created untouched', (tester) async {
    NewNotebookResult? result;
    await openDialog(tester, (r) => result = r);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result?.title, 'Untitled notebook');
    expect(result?.template, PaperTemplate.blank);
    expect(result?.coverColorValue, CoverPalette.colors.first.toARGB32());
  });

  testWidgets('blocks an empty title', (tester) async {
    NewNotebookResult? result;
    await openDialog(tester, (r) => result = r);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('returns the selected paper template', (tester) async {
    NewNotebookResult? result;
    await openDialog(tester, (r) => result = r);

    await tester.tap(find.text('Grid'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result?.template, PaperTemplate.grid);
  });

  testWidgets('cancel returns null', (tester) async {
    NewNotebookResult? result;
    var closed = false;
    await openDialog(tester, (r) {
      result = r;
      closed = true;
    });

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });
}
