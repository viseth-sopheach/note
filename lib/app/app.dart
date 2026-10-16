import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/settings_providers.dart';
import '../features/settings/domain/app_theme_mode.dart';
import '../features/settings/domain/layout_density.dart';
import '../features/sharing/presentation/share_intent_listener.dart';
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
    final accent = ref.watch(
      appSettingsProvider.select((s) => s.accentColorValue),
    );
    final compact = ref.watch(
      appSettingsProvider.select((s) => s.density == LayoutDensity.compact),
    );
    final seed = Color(accent);

    return MaterialApp.router(
      title: 'VisethNote',
      theme: AppTheme.build(Brightness.light, seed: seed, compact: compact),
      darkTheme: AppTheme.build(Brightness.dark, seed: seed, compact: compact),
      themeMode: _toThemeMode(mode),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ShareIntentListener(child: child!),
    );
  }
}
