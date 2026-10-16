import 'app_settings.dart';
import 'app_theme_mode.dart';
import 'editor_position.dart';

abstract interface class SettingsRepository {
  /// Always returns valid, normalized settings. Missing or corrupt stored
  /// values fall back to defaults.
  AppSettings load();

  Future<void> save(AppSettings settings);

  EditorPosition? loadEditorPosition(String notebookId);

  Future<void> saveEditorPosition(String notebookId, EditorPosition position);

  AppThemeMode get themeMode;

  Future<void> setThemeMode(AppThemeMode mode);
}
