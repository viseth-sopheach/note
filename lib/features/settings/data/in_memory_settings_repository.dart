import '../domain/app_theme_mode.dart';
import '../domain/settings_repository.dart';

class InMemorySettingsRepository implements SettingsRepository {
  AppThemeMode _themeMode = AppThemeMode.system;

  @override
  AppThemeMode get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async => _themeMode = mode;
}