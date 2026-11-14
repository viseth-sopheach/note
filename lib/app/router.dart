import 'package:go_router/go_router.dart';

import '../features/editor/presentation/dual_document_screen.dart';
import '../features/editor/presentation/editor_screen.dart';
import '../features/sharing/presentation/import_pdf_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/pdf_viewer/presentation/pdf_viewer_screen.dart';
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
      path: AppRoutes.importPdf,
      builder: (context, state) =>
          ImportPdfScreen(paths: (state.extra as List<String>?) ?? const []),
    ),
    GoRoute(
      path: AppRoutes.dualPattern,
      builder: (context, state) => DualDocumentScreen(
        firstId: state.pathParameters['a']!,
        secondId: state.pathParameters['b']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.pdfViewer,
      builder: (context, state) {
        final args = state.extra! as ({String path, String title});
        return PdfViewerScreen(filePath: args.path, title: args.title);
      },
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
