import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/settings/application/settings_providers.dart';
import 'package:quill_notes/features/settings/data/in_memory_settings_repository.dart';
import 'package:quill_notes/features/settings/domain/app_theme_mode.dart';

void main() {
  test('theme mode defaults to system and saves changes', () async {
    final repo = InMemorySettingsRepository();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    expect(container.read(appThemeModeProvider), AppThemeMode.system);

    await container
        .read(appSettingsProvider.notifier)
        .setMode(AppThemeMode.dark);

    expect(container.read(appThemeModeProvider), AppThemeMode.dark);
    expect(repo.themeMode, AppThemeMode.dark);
  });

  test('unknown stored name falls back to system', () {
    expect(AppThemeMode.fromName('nope'), AppThemeMode.system);
    expect(AppThemeMode.fromName(null), AppThemeMode.system);
  });
}
