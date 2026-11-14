abstract final class AppRoutes {
  static const String library = '/';
  static const String settings = '/settings';
  static const String settingsToolbar = '/settings/toolbar';
  static const String pdfViewer = '/pdf';
  static const String importPdf = '/import';
  static const String folderPattern = '/folder/:id';
  static const String notebookPattern = '/notebook/:id';
  static const String dualPattern = '/dual/:a/:b';

  static String folder(String id) => '/folder/$id';
  static String notebook(String id) => '/notebook/$id';
  static String dual(String a, String b) => '/dual/$a/$b';
}
