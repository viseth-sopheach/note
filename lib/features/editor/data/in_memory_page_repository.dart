import 'dart:typed_data';

import '../domain/page_repository.dart';
import '../domain/stroke.dart';
import '../domain/stroke_codec.dart';

class InMemoryPageRepository implements PageRepository {
  final Map<String, Uint8List> _pages = {};

  /// Number of completed saves. Useful in tests.
  int saveCount = 0;

  String _key(String notebookId, int pageIndex) => '$notebookId#$pageIndex';

  @override
  Future<List<Stroke>> loadStrokes(
    String notebookId, {
    int pageIndex = 0,
  }) async {
    final bytes = _pages[_key(notebookId, pageIndex)];
    if (bytes == null || bytes.isEmpty) return const [];
    return StrokeCodec.decode(bytes);
  }

  @override
  Future<void> saveStrokes(
    String notebookId,
    List<Stroke> strokes, {
    int pageIndex = 0,
  }) async {
    _pages[_key(notebookId, pageIndex)] = StrokeCodec.encode(strokes);
    saveCount++;
  }
}