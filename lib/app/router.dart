import 'package:go_router/go_router.dart';

import '../features/editor/presentation/editor_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/toolbar_settings_screen.dart';
import 'routes.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.library,
  routes: [
    GoRoute(
      path: AppRoutes.library,
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: AppRoutes.folderPattern,
      builder: (context, state) =>
          LibraryScreen(folderId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.notebookPattern,
      builder: (context, state) =>
          EditorScreen(notebookId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.settingsToolbar,
      builder: (context, state) => const ToolbarSettingsScreen(),
    ),
  ],
);
