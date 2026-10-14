import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/in_memory_settings_repository.dart';
import '../domain/app_theme_mode.dart';
import '../domain/settings_repository.dart';

/// Overridden in main.dart with the persistent implementation.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => InMemorySettingsRepository(),
);

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => ref.read(settingsRepositoryProvider).themeMode;

  Future<void> setMode(AppThemeMode mode) async {
    await ref.read(settingsRepositoryProvider).setThemeMode(mode);
    state = mode;
  }
}

final appThemeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);