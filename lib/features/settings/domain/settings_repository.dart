import 'app_theme_mode.dart';

abstract interface class SettingsRepository {
  AppThemeMode get themeMode;

  Future<void> setThemeMode(AppThemeMode mode);
}