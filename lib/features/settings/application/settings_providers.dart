import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/in_memory_settings_repository.dart';
import '../domain/app_settings.dart';
import '../domain/app_theme_mode.dart';
import '../domain/settings_repository.dart';

/// Overridden in main.dart with the persistent implementation.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => InMemorySettingsRepository(),
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsRepositoryProvider).load();

  /// Applies [change], keeps the result valid, shows it immediately and
  /// persists it. A failed write is logged and the change stays for this
  /// session.
  Future<void> update(AppSettings Function(AppSettings current) change) async {
    final next = change(state).normalized();
    state = next;
    try {
      await ref.read(settingsRepositoryProvider).save(next);
    } catch (error, stack) {
      developer.log(
        'Saving settings failed',
        name: 'settings',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> setMode(AppThemeMode mode) =>
      update((s) => s.copyWith(themeMode: mode));
}

final appSettingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Kept for existing callers. Change the mode with
/// `appSettingsProvider.notifier.setMode`.
final appThemeModeProvider = Provider<AppThemeMode>(
  (ref) => ref.watch(appSettingsProvider.select((s) => s.themeMode)),
);

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);
