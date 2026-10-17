import 'dart:math' as math;
import 'dart:typed_data';

import '../../library/domain/paper_template.dart';
import '../domain/page_repository.dart';
import '../domain/stroke.dart';
import '../domain/stroke_codec.dart';

class _StoredPage {
  const _StoredPage(this.bytes, this.template, [this.imagePath]);

  final Uint8List bytes;
  final PaperTemplate? template;
  final String? imagePath;
}

class InMemoryPageRepository implements PageRepository {
  final Map<String, Map<int, _StoredPage>> _notebooks = {};

  /// Number of completed saves. Useful in tests.
  int saveCount = 0;

  Map<int, _StoredPage> _pagesOf(String notebookId) =>
      _notebooks.putIfAbsent(notebookId, () => {});

  @override
  Future<List<Stroke>> loadStrokes(
    String notebookId, {
    int pageIndex = 0,
  }) async {
    final page = _notebooks[notebookId]?[pageIndex];
    if (page == null || page.bytes.isEmpty) return const [];
    return StrokeCodec.decode(page.bytes);
  }

  @override
  Future<PaperTemplate?> loadTemplate(
    String notebookId, {
    int pageIndex = 0,
  }) async => _notebooks[notebookId]?[pageIndex]?.template;

  @override
  Future<String?> loadImagePath(String notebookId, {int pageIndex = 0}) async =>
      _notebooks[notebookId]?[pageIndex]?.imagePath;

  @override
  Future<void> saveStrokes(
    String notebookId,
    List<Stroke> strokes, {
    int pageIndex = 0,
  }) async {
    final pages = _pagesOf(notebookId);
    final old = pages[pageIndex];
    pages[pageIndex] = _StoredPage(
      StrokeCodec.encode(strokes),
      old?.template,
      old?.imagePath,
    );
    saveCount++;
  }

  @override
  Future<int> pageCount(String notebookId) async {
    final pages = _notebooks[notebookId];
    if (pages == null || pages.isEmpty) return 0;
    return pages.keys.reduce(math.max) + 1;
  }

  @override
  Future<void> insertPage(
    String notebookId, {
    required int pageIndex,
    required PaperTemplate template,
    List<Stroke> strokes = const [],
    String? imagePath,
  }) async {
    if (pageIndex < 0) {
      throw ArgumentError.value(pageIndex, 'pageIndex', 'Must not be negative');
    }
    final blob = StrokeCodec.encode(strokes);
    final pages = _pagesOf(notebookId);
    final shifted = <int, _StoredPage>{
      for (final e in pages.entries)
        (e.key >= pageIndex ? e.key + 1 : e.key): e.value,
    };
    shifted[pageIndex] = _StoredPage(blob, template, imagePath);
    _notebooks[notebookId] = shifted;
  }

  @override
  Future<void> deletePage(String notebookId, int pageIndex) async {
    final pages = _notebooks[notebookId];
    if (pages == null) return;
    _notebooks[notebookId] = <int, _StoredPage>{
      for (final e in pages.entries)
        if (e.key != pageIndex)
          (e.key > pageIndex ? e.key - 1 : e.key): e.value,
    };
  }
}
