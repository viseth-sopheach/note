import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/database/app_database_provider.dart';
import '../data/drift_page_repository.dart';
import '../domain/page_repository.dart';

final pageRepositoryProvider = Provider<PageRepository>(
  (ref) => DriftPageRepository(ref.watch(appDatabaseProvider)),
);
