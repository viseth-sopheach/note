import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/settings/application/settings_providers.dart';
import 'features/settings/data/shared_prefs_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          SharedPrefsSettingsRepository(prefs),
        ),
      ],
      child: const NoteApp(),
    ),
  );
}
