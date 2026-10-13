abstract final class AppRoutes {
  static const String library = '/';
  static const String settings = '/settings';
  static const String folderPattern = '/folder/:id';
  static const String notebookPattern = '/notebook/:id';

  static String folder(String id) => '/folder/$id';
  static String notebook(String id) => '/notebook/$id';
}