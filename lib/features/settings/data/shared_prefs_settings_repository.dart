import 'package:shared_preferences/shared_preferences.dart';

import '../../editor/domain/stroke_tool.dart';
import '../../library/domain/paper_template.dart';
import '../domain/app_settings.dart';
import '../domain/app_theme_mode.dart';
import '../domain/editor_position.dart';
import '../domain/layout_density.dart';
import '../domain/settings_repository.dart';

class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);

  static const String _theme = 'theme_mode';
  static const String _accent = 'accent_color';
  static const String _density = 'layout_density';
  static const String _covers = 'show_covers';
  static const String _template = 'default_template';
  static const String _tool = 'default_tool';
  static const String _penColor = 'pen_color';
  static const String _penWidth = 'pen_width';
  static const String _hlColor = 'highlighter_color';
  static const String _hlWidth = 'highlighter_width';
  static const String _zoom = 'default_zoom';
  static const String _wheel = 'wheel_zoom';
  static const String _order = 'toolbar_order';
  static const String _hidden = 'toolbar_hidden';
  static const String _undo = 'undo_limit';
  static const String _confirm = 'confirm_delete_page';
  static const String _remember = 'remember_position';
  static const String _shapes = 'shape_recognition';
  static const String _positionPrefix = 'editor_position_';

  final SharedPreferences _prefs;

  /// A value stored with another type must not crash the app.
  T? _safe<T>(T? Function() read) {
    try {
      return read();
    } catch (_) {
      return null;
    }
  }

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static List<StrokeTool> _tools(List<String>? names) => [
    for (final name in names ?? const <String>[])
      for (final tool in StrokeTool.values)
        if (tool.name == name) tool,
  ];

  @override
  AppSettings load() {
    const d = AppSettings();
    return AppSettings(
      themeMode: AppThemeMode.fromName(_safe(() => _prefs.getString(_theme))),
      accentColorValue:
          _safe(() => _prefs.getInt(_accent)) ?? d.accentColorValue,
      density: LayoutDensity.fromName(_safe(() => _prefs.getString(_density))),
      showCovers: _safe(() => _prefs.getBool(_covers)) ?? d.showCovers,
      defaultTemplate: _enum(
        PaperTemplate.values,
        _safe(() => _prefs.getString(_template)),
        d.defaultTemplate,
      ),
      defaultTool: _enum(
        StrokeTool.values,
        _safe(() => _prefs.getString(_tool)),
        d.defaultTool,
      ),
      penColorValue: _safe(() => _prefs.getInt(_penColor)) ?? d.penColorValue,
      penWidth: _safe(() => _prefs.getDouble(_penWidth)) ?? d.penWidth,
      highlighterColorValue:
          _safe(() => _prefs.getInt(_hlColor)) ?? d.highlighterColorValue,
      highlighterWidth:
          _safe(() => _prefs.getDouble(_hlWidth)) ?? d.highlighterWidth,
      defaultZoom: _safe(() => _prefs.getDouble(_zoom)) ?? d.defaultZoom,
      wheelZoom: _safe(() => _prefs.getBool(_wheel)) ?? d.wheelZoom,
      toolbarOrder: _tools(_safe(() => _prefs.getStringList(_order))),
      hiddenTools: _tools(_safe(() => _prefs.getStringList(_hidden))).toSet(),
      undoLimit: _safe(() => _prefs.getInt(_undo)) ?? d.undoLimit,
      confirmDeletePage:
          _safe(() => _prefs.getBool(_confirm)) ?? d.confirmDeletePage,
      rememberPosition:
          _safe(() => _prefs.getBool(_remember)) ?? d.rememberPosition,
      shapeRecognition:
          _safe(() => _prefs.getBool(_shapes)) ?? d.shapeRecognition,
    ).normalized();
  }

  @override
  Future<void> save(AppSettings settings) async {
    final s = settings.normalized();
    await Future.wait([
      _prefs.setString(_theme, s.themeMode.name),
      _prefs.setInt(_accent, s.accentColorValue),
      _prefs.setString(_density, s.density.name),
      _prefs.setBool(_covers, s.showCovers),
      _prefs.setString(_template, s.defaultTemplate.name),
      _prefs.setString(_tool, s.defaultTool.name),
      _prefs.setInt(_penColor, s.penColorValue),
      _prefs.setDouble(_penWidth, s.penWidth),
      _prefs.setInt(_hlColor, s.highlighterColorValue),
      _prefs.setDouble(_hlWidth, s.highlighterWidth),
      _prefs.setDouble(_zoom, s.defaultZoom),
      _prefs.setBool(_wheel, s.wheelZoom),
      _prefs.setStringList(_order, [for (final t in s.toolbarOrder) t.name]),
      _prefs.setStringList(_hidden, [for (final t in s.hiddenTools) t.name]),
      _prefs.setInt(_undo, s.undoLimit),
      _prefs.setBool(_confirm, s.confirmDeletePage),
      _prefs.setBool(_remember, s.rememberPosition),
      _prefs.setBool(_shapes, s.shapeRecognition),
    ]);
  }

  @override
  EditorPosition? loadEditorPosition(String notebookId) =>
      EditorPosition.tryParse(
        _safe(() => _prefs.getString('$_positionPrefix$notebookId')),
      );

  @override
  Future<void> saveEditorPosition(
    String notebookId,
    EditorPosition position,
  ) async {
    await _prefs.setString('$_positionPrefix$notebookId', position.encode());
  }

  @override
  AppThemeMode get themeMode => load().themeMode;

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      save(load().copyWith(themeMode: mode));
}
