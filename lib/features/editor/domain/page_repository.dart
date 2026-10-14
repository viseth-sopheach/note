import 'stroke.dart';

/// Storage contract for page content. The UI depends on this interface only.
abstract interface class PageRepository {
  /// Strokes of the page, or an empty list when nothing was saved yet.
  /// Throws [FormatException] when saved data is corrupt.
  Future<List<Stroke>> loadStrokes(String notebookId, {int pageIndex = 0});

  /// Replaces the stored strokes of the page.
  Future<void> saveStrokes(
    String notebookId,
    List<Stroke> strokes, {
    int pageIndex = 0,
  });

  /// Highest saved page index + 1, or 0 when nothing was saved yet.
  Future<int> pageCount(String notebookId);
}