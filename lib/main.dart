import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/library/application/pinned_notes.dart';
import 'features/settings/application/settings_providers.dart';
import 'features/settings/data/shared_prefs_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize(); // required in pdfrx 2.x
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'Flutter error',
      name: 'app',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log('Uncaught', name: 'app', error: error, stackTrace: stack);
    return true;
  };
  PaintingBinding.instance.imageCache
    ..maximumSize = 50
    ..maximumSizeBytes = 80 << 20;

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        settingsRepositoryProvider.overrideWithValue(
          SharedPrefsSettingsRepository(prefs),
        ),
      ],
      child: const NoteApp(),
    ),
  );
}
