import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/database/app_database_provider.dart';
import '../data/drift_page_repository.dart';
import '../data/handwriting_recognizer_factory.dart';
import '../domain/handwriting_recognizer.dart';
import '../domain/page_repository.dart';

final pageRepositoryProvider = Provider<PageRepository>(
  (ref) => DriftPageRepository(ref.watch(appDatabaseProvider)),
);

final handwritingRecognizerProvider = Provider<HandwritingRecognizer>((ref) {
  final recognizer = createHandwritingRecognizer();
  ref.onDispose(() => unawaited(recognizer.dispose()));
  return recognizer;
});
