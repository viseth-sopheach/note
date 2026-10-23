import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/page_image.dart';
import '../domain/page_repository.dart';

enum ImageCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Images of one page: selection, move, resize, delete and debounced saving.
/// Images always stay fully inside the paper.
class PageImagesController extends ChangeNotifier {
  PageImagesController({
    required PageRepository repository,
    required this.notebookId,
    required this.pageIndex,
    required this.pageSize,
    List<PageImage> initial = const [],
    this.delay = const Duration(milliseconds: 600),
    this.retryDelay = const Duration(seconds: 5),
    String Function()? idGenerator,
  }) : _repository = repository,
       _newId = idGenerator ?? (() => const Uuid().v4()) {
    _images = [for (final i in initial) _normalized(i)];
  }

  static const double minSide = 48;

  /// Handle radius; also the extra area around the selection that is grabbed.
  static const double handleReach = 16;
  static const double _initialFraction = 0.6;

  final PageRepository _repository;
  final String notebookId;
  final Size pageSize;
  final Duration delay;
  final Duration retryDelay;
  final String Function() _newId;

  /// Changes when pages before this one are added or deleted.
  int pageIndex;

  late List<PageImage> _images;
  String? _selectedId;
  bool _interacting = false;
  bool _dirty = false;
  bool _closed = false;
  Timer? _timer;
  Future<void> _tail = Future<void>.value();

  List<PageImage> get images => UnmodifiableListView(_images);
  String? get selectedId => _selectedId;
  bool get interacting => _interacting;
  bool get hasUnsavedChanges => _dirty;

  PageImage? get selected {
    final i = _indexOf(_selectedId);
    return i < 0 ? null : _images[i];
  }

  // ---- Editing ----

  /// Adds an image centered on [center] (paper units) and selects it.
  PageImage add({
    required String path,
    required Size natural,
    required Offset center,
  }) {
    if (natural.width <= 0 || natural.height <= 0) {
      throw ArgumentError.value(natural, 'natural', 'Must be positive');
    }
    final fit = math.min(
      1.0,
      math.min(
        pageSize.width * _initialFraction / natural.width,
        pageSize.height * _initialFraction / natural.height,
      ),
    );
    var w = natural.width * fit;
    var h = natural.height * fit;
    final shortest = math.min(w, h);
    if (shortest < minSide) {
      w *= minSide / shortest;
      h *= minSide / shortest;
    }
    w = _bound(w, minSide, pageSize.width);
    h = _bound(h, minSide, pageSize.height);

    final image = PageImage(
      id: _newId(),
      path: path,
      x: _bound(center.dx - w / 2, 0, pageSize.width - w),
      y: _bound(center.dy - h / 2, 0, pageSize.height - h),
      width: w,
      height: h,
    );
    _images.add(image);
    _selectedId = image.id;
    _markChanged();
    return image;
  }

  void select(String? id) {
    if (_selectedId == id) return;
    if (id != null && _indexOf(id) < 0) return;
    _selectedId = id;
    notifyListeners();
  }

  void beginInteraction() {
    if (_interacting) return;
    _interacting = true;
    notifyListeners();
  }

  void endInteraction() {
    if (!_interacting) return;
    _interacting = false;
    notifyListeners();
  }

  void moveBy(String id, double dx, double dy) {
    final i = _indexOf(id);
    if (i < 0) return;
    final img = _images[i];
    final x = _bound(img.x + dx, 0, pageSize.width - img.width);
    final y = _bound(img.y + dy, 0, pageSize.height - img.height);
    if (x == img.x && y == img.y) return;
    _images[i] = img.copyWith(x: x, y: y);
    _markChanged();
  }

  /// Resizes from [corner] keeping the opposite corner fixed and the aspect
  /// ratio unchanged. [dx] and [dy] are drag deltas in paper units.
  void resizeBy(String id, ImageCorner corner, double dx, double dy) {
    final i = _indexOf(id);
    if (i < 0) return;
    final img = _images[i];
    final left =
        corner == ImageCorner.topLeft || corner == ImageCorner.bottomLeft;
    final top =
        corner == ImageCorner.topLeft || corner == ImageCorner.topRight;

    final fromX = left ? -dx : dx;
    final fromY = (top ? -dy : dy) * img.aspect;
    final availW = left ? img.x + img.width : pageSize.width - img.x;
    final availH = top ? img.y + img.height : pageSize.height - img.y;
    final maxW = math.min(availW, availH * img.aspect);
    final minW = math.min(minSide * math.max(1, img.aspect), maxW);

    final w = _bound(img.width + (fromX + fromY) / 2, minW, maxW);
    final h = w / img.aspect;
    if (w == img.width) return;

    _images[i] = img.copyWith(
      x: left ? img.x + img.width - w : img.x,
      y: top ? img.y + img.height - h : img.y,
      width: w,
      height: h,
    );
    _markChanged();
  }

  void deleteSelected() {
    final i = _indexOf(_selectedId);
    if (i < 0) return;
    _images.removeAt(i);
    _selectedId = null;
    _interacting = false;
    _markChanged();
  }

  // ---- Hit testing (paper units) ----

  PageImage? imageAt(Offset p) {
    for (var i = _images.length - 1; i >= 0; i--) {
      if (_rect(_images[i]).contains(p)) return _images[i];
    }
    return null;
  }

  bool hitsSelectedChrome(Offset p) {
    final s = selected;
    return s != null && _rect(s).inflate(handleReach).contains(p);
  }

  /// True when a pointer-down at [p] belongs to an image, not to drawing.
  bool claims(Offset p, {required bool selectToolActive}) =>
      hitsSelectedChrome(p) || (selectToolActive && imageAt(p) != null);

  // ---- Saving ----

  void _markChanged() {
    _dirty = true;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  /// Saves now when there are unsaved changes. Saves never overlap.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (!_dirty) return _tail;

    _dirty = false;
    final snapshot = List<PageImage>.of(_images);
    final index = pageIndex;
    return _tail = _tail.then((_) => _write(snapshot, index));
  }

  Future<void> _write(List<PageImage> snapshot, int index) async {
    try {
      await _repository.saveImages(notebookId, snapshot, pageIndex: index);
    } catch (error, stack) {
      developer.log(
        'Saving page images failed',
        name: 'editor',
        error: error,
        stackTrace: stack,
      );
      _dirty = true;
      if (!_closed) {
        _timer?.cancel();
        _timer = Timer(retryDelay, () => unawaited(flush()));
      }
    }
  }

  /// Saves pending changes, then points the controller at a new page index.
  Future<void> rebind(int index) async {
    if (pageIndex == index) return;
    await flush();
    pageIndex = index;
  }

  /// Saves pending changes and releases the controller.
  Future<void> close() async {
    _closed = true;
    _timer?.cancel();
    await flush();
    dispose();
  }

  // ---- Helpers ----

  int _indexOf(String? id) =>
      id == null ? -1 : _images.indexWhere((i) => i.id == id);

  Rect _rect(PageImage i) => Rect.fromLTWH(i.x, i.y, i.width, i.height);

  static double _bound(double v, double lo, double hi) =>
      hi < lo ? lo : v.clamp(lo, hi).toDouble();

  /// Forces loaded data to fit on the paper.
  PageImage _normalized(PageImage i) {
    final scale = math.min(
      1.0,
      math.min(pageSize.width / i.width, pageSize.height / i.height),
    );
    final w = i.width * scale;
    final h = i.height * scale;
    return PageImage(
      id: i.id,
      path: i.path,
      x: _bound(i.x, 0, pageSize.width - w),
      y: _bound(i.y, 0, pageSize.height - h),
      width: w,
      height: h,
    );
  }
}