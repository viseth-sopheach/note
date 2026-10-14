import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_theme_mode.dart';
import '../domain/settings_repository.dart';

class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);

  static const String _themeKey = 'theme_mode';

  final SharedPreferences _prefs;

  @override
  AppThemeMode get themeMode =>
      AppThemeMode.fromName(_prefs.getString(_themeKey));

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
  }
}