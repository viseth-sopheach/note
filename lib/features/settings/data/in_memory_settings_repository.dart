import '../domain/app_settings.dart';
import '../domain/app_theme_mode.dart';
import '../domain/editor_position.dart';
import '../domain/settings_repository.dart';

class InMemorySettingsRepository implements SettingsRepository {
  AppSettings _settings = const AppSettings();
  final Map<String, EditorPosition> _positions = {};

  @override
  AppSettings load() => _settings.normalized();

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;

  @override
  EditorPosition? loadEditorPosition(String notebookId) =>
      _positions[notebookId];

  @override
  Future<void> saveEditorPosition(
    String notebookId,
    EditorPosition position,
  ) async => _positions[notebookId] = position;

  @override
  AppThemeMode get themeMode => load().themeMode;

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      save(load().copyWith(themeMode: mode));
}
