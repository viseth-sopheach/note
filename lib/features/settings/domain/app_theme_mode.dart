enum AppThemeMode {
  system('System'),
  light('Light'),
  dark('Dark');

  const AppThemeMode(this.label);

  final String label;

  static AppThemeMode fromName(String? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return AppThemeMode.system;
  }
}
