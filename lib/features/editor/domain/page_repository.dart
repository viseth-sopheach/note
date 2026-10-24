import '../../library/domain/paper_template.dart';
import 'page_text.dart';
import 'stroke.dart';
import 'page_image.dart';

/// Storage contract for page content. The UI depends on this interface only.
abstract interface class PageRepository {
  /// Strokes of the page, or an empty list when nothing was saved yet.
  /// Throws [FormatException] when saved data is corrupt.
  Future<List<Stroke>> loadStrokes(String notebookId, {int pageIndex = 0});

  /// Replaces the stored strokes of the page. Keeps the page template.
  Future<void> saveStrokes(
    String notebookId,
    List<Stroke> strokes, {
    int pageIndex = 0,
  });

  /// Highest saved page index + 1, or 0 when nothing was saved yet.
  Future<int> pageCount(String notebookId);

  /// Template chosen for the page, or null when it follows the notebook.
  Future<PaperTemplate?> loadTemplate(String notebookId, {int pageIndex = 0});

  /// Background image path of the page, or null.
  Future<String?> loadImagePath(String notebookId, {int pageIndex = 0});

  /// Images placed on the page, or an empty list.
  Future<List<PageImage>> loadImages(String notebookId, {int pageIndex = 0});

  /// Replaces the images of the page. Keeps strokes and template.
  Future<void> saveImages(
    String notebookId,
    List<PageImage> images, {
    int pageIndex = 0,
  });

  /// Text boxes placed on the page, or an empty list.
  Future<List<PageText>> loadTexts(String notebookId, {int pageIndex = 0});

  /// Replaces the text boxes of the page. Keeps strokes, images and template.
  Future<void> saveTexts(
    String notebookId,
    List<PageText> texts, {
    int pageIndex = 0,
  });

  /// Inserts a page at [pageIndex]; pages at or after it move down by one.
  /// Throws [ArgumentError] when [pageIndex] is negative.
  Future<void> insertPage(
    String notebookId, {
    required int pageIndex,
    required PaperTemplate template,
    List<Stroke> strokes = const [],
    String? imagePath,
    List<PageImage> images = const [],
    List<PageText> texts = const [],
  });

  /// Deletes the page; later pages move up by one. Missing page is a no-op.
  Future<void> deletePage(String notebookId, int pageIndex);
}
