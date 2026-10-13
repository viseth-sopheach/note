import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Quill Notes',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}