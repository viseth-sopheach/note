import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/application/editor_providers.dart';
import 'drive_service.dart';
import 'export_service.dart';
import 'import_service.dart';
import 'share_service.dart';
import 'telegram_service.dart';

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref),
);

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(ref.watch(pageRepositoryProvider)),
);

final shareServiceProvider = Provider<ShareService>((ref) => ShareService());

final telegramServiceProvider = Provider<TelegramService>(
  (ref) => TelegramService(),
);

final driveServiceProvider = Provider<DriveService>((ref) => DriveService());
