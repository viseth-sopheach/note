import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/app/app.dart';

void main() {
  testWidgets('app starts on the library screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NoteApp()));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('No notebooks yet'), findsOneWidget);
  });
}