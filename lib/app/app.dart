import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/settings_providers.dart';
import '../features/settings/domain/app_theme_mode.dart';
import 'router.dart';
import 'theme.dart';

class NoteApp extends ConsumerWidget {
  const NoteApp({super.key});

  static ThemeMode _toThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: 'VisethNote',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _toThemeMode(mode),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}