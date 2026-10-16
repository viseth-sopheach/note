import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';
import 'package:quill_notes/features/editor/domain/toolbar_layout.dart';
import 'package:quill_notes/features/library/domain/paper_template.dart';
import 'package:quill_notes/features/settings/application/settings_providers.dart';
import 'package:quill_notes/features/settings/data/in_memory_settings_repository.dart';
import 'package:quill_notes/features/settings/data/shared_prefs_settings_repository.dart';
import 'package:quill_notes/features/settings/domain/app_settings.dart';
import 'package:quill_notes/features/settings/domain/app_theme_mode.dart';
import 'package:quill_notes/features/settings/domain/editor_position.dart';
import 'package:quill_notes/features/settings/domain/layout_density.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPrefsSettingsRepository> repoWith(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPrefsSettingsRepository(await SharedPreferences.getInstance());
  }

  test('first launch returns defaults', () async {
    final s = (await repoWith({})).load();
    expect(s.themeMode, AppThemeMode.system);
    expect(s.defaultTemplate, PaperTemplate.blank);
    expect(s.density, LayoutDensity.comfortable);
    expect(s.showCovers, isTrue);
    expect(s.undoLimit, 200);
    expect(s.confirmDeletePage, isTrue);
    expect(s.toolbarOrder, StrokeTool.values);
    expect(s.hiddenTools, isEmpty);
  });

  test('saved settings load back after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await SharedPrefsSettingsRepository(prefs).save(
      const AppSettings(
        themeMode: AppThemeMode.dark,
        defaultTemplate: PaperTemplate.grid,
        density: LayoutDensity.compact,
        showCovers: false,
        penWidth: 4,
        undoLimit: 50,
        toolbarOrder: [
          StrokeTool.select,
          StrokeTool.pen,
          StrokeTool.highlighter,
          StrokeTool.eraser,
        ],
        hiddenTools: {StrokeTool.eraser},
      ),
    );

    final s = SharedPrefsSettingsRepository(prefs).load();
    expect(s.themeMode, AppThemeMode.dark);
    expect(s.defaultTemplate, PaperTemplate.grid);
    expect(s.density, LayoutDensity.compact);
    expect(s.showCovers, isFalse);
    expect(s.penWidth, 4);
    expect(s.undoLimit, 50);
    expect(s.toolbarOrder.first, StrokeTool.select);
    expect(s.hiddenTools, {StrokeTool.eraser});
  });

  test('invalid or wrongly typed values fall back to defaults', () async {
    final s = (await repoWith({
      'theme_mode': 'nope',
      'default_template': 'zzz',
      'accent_color': 'oops',
      'pen_width': 3.5,
      'undo_limit': 7,
      'toolbar_order': ['pen', 'pen', 'bogus'],
      'toolbar_hidden': ['pen', 'highlighter', 'eraser', 'select'],
    })).load();

    expect(s.themeMode, AppThemeMode.system);
    expect(s.defaultTemplate, PaperTemplate.blank);
    expect(s.accentColorValue, const AppSettings().accentColorValue);
    expect(s.penWidth, 2);
    expect(s.undoLimit, 200);
    expect(s.toolbarOrder, StrokeTool.values);
    expect(s.hiddenTools, isEmpty);
  });

  test('editor position round trips and rejects garbage', () async {
    final repo = await repoWith({'editor_position_bad': 'x;y'});
    expect(repo.loadEditorPosition('n1'), isNull);
    expect(repo.loadEditorPosition('bad'), isNull);

    await repo.saveEditorPosition(
      'n1',
      const EditorPosition(pageIndex: 3, offset: -12.5),
    );
    expect(
      repo.loadEditorPosition('n1'),
      const EditorPosition(pageIndex: 3, offset: -12.5),
    );
  });

  test('notifier applies and persists updates', () async {
    final repo = InMemorySettingsRepository();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container
        .read(appSettingsProvider.notifier)
        .update((s) => s.copyWith(defaultTemplate: PaperTemplate.dotted));

    expect(
      container.read(appSettingsProvider).defaultTemplate,
      PaperTemplate.dotted,
    );
    expect(repo.load().defaultTemplate, PaperTemplate.dotted);
  });

  group('ToolbarLayout', () {
    test('keeps the order and drops hidden tools', () {
      final tools = ToolbarLayout.visible(
        order: const [StrokeTool.select, StrokeTool.pen],
        hidden: const {StrokeTool.eraser},
        active: StrokeTool.pen,
      );
      expect(tools.take(2), [StrokeTool.select, StrokeTool.pen]);
      expect(tools, isNot(contains(StrokeTool.eraser)));
      expect(tools, contains(StrokeTool.highlighter));
    });

    test('the active tool is never hidden', () {
      final tools = ToolbarLayout.visible(
        order: StrokeTool.values,
        hidden: const {StrokeTool.pen},
        active: StrokeTool.pen,
      );
      expect(tools, contains(StrokeTool.pen));
    });
  });
}
