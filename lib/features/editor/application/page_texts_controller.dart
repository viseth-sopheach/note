import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/page_repository.dart';
import '../domain/page_text.dart';

/// Text boxes of one page: selection, editing, move, resize, delete and
/// debounced saving. Boxes always stay fully inside the paper.
class PageTextsController extends ChangeNotifier {
  PageTextsController({
    required PageRepository repository,
    required this.notebookId,
    required this.pageIndex,
    required this.pageSize,
    List<PageText> initial = const [],
    this.delay = const Duration(milliseconds: 600),
    this.retryDelay = const Duration(seconds: 5),
    String Function()? idGenerator,
  }) : _repository = repository,
       _newId = idGenerator ?? (() => const Uuid().v4()) {
    _texts = [
      for (final t in initial)
        if (t.text.trim().isNotEmpty) _normalized(t),
    ];
  }

  static const double minWidth = 80;
  static const double minHeight = 36;
  static const double handleReach = 16;
  static const double innerPadding = 6;
  static const double defaultWidth = 240;
  static const double defaultHeight = 44;
  static const double defaultFontSize = 20;

  final PageRepository _repository;
  final String notebookId;
  final Size pageSize;
  final Duration delay;
  final Duration retryDelay;
  final String Function() _newId;

  /// Changes when pages before this one are added or deleted.
  int pageIndex;

  late List<PageText> _texts;
  String? _selectedId;
  String? _editingId;
  bool _interacting = false;
  bool _dirty = false;
  bool _closed = false;

  /// Toolbar area in paper units, set by TextLayer so taps on it are not
  /// treated as drawing.
  Rect? toolbarRect;

  Timer? _timer;
  Future<void> _tail = Future<void>.value();

  List<PageText> get texts => UnmodifiableListView(_texts);
  String? get selectedId => _selectedId;
  String? get editingId => _editingId;
  bool get interacting => _interacting;
  bool get hasUnsavedChanges => _dirty;

  // ---- Editing ----

  /// Adds an empty box with its top-left corner at [at] (paper units),
  /// selects it and starts editing.
  PageText add({required Offset at, required int colorValue}) {
    final w = math.min(defaultWidth, pageSize.width);
    final h = math.min(defaultHeight, pageSize.height);
    final text = PageText(
      id: _newId(),
      text: '',
      x: _bound(at.dx, 0, pageSize.width - w),
      y: _bound(at.dy, 0, pageSize.height - h),
      width: w,
      height: h,
      colorValue: colorValue,
      fontSize: defaultFontSize,
    );
    _texts.add(text);
    _selectedId = text.id;
    _editingId = text.id;
    _markChanged();
    return text;
  }

  /// Selects a box, or clears the selection with null. A box left empty is
  /// removed.
  void select(String? id) {
    if (_selectedId == id) return;
    if (id != null && _indexOf(id) < 0) return;
    _dropIfEmpty(_selectedId);
    _selectedId = id;
    if (_editingId != id) _editingId = null;
    notifyListeners();
  }

  void startEditing(String id) {
    if (_indexOf(id) < 0) return;
    if (_selectedId != id) _dropIfEmpty(_selectedId);
    _selectedId = id;
    _editingId = id;
    notifyListeners();
  }

  /// Sets the text. The box grows to [neededHeight] but never shrinks.
  void setText(String id, String text, {required double neededHeight}) {
    final i = _indexOf(id);
    if (i < 0) return;
    final t = _texts[i];
    final h = _bound(
      math.max(t.height, neededHeight),
      minHeight,
      pageSize.height - t.y,
    );
    if (t.text == text && h == t.height) return;
    _texts[i] = t.copyWith(text: text, height: h);
    _markChanged();
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
    final t = _texts[i];
    final x = _bound(t.x + dx, 0, pageSize.width - t.width);
    final y = _bound(t.y + dy, 0, pageSize.height - t.height);
    if (x == t.x && y == t.y) return;
    _texts[i] = t.copyWith(x: x, y: y);
    _markChanged();
  }

  /// Drags a handle. [fx] and [fy] are -1 (left/top), 1 (right/bottom) or 0.
  /// [dx] and [dy] are drag deltas in paper units.
  void resize(String id, int fx, int fy, double dx, double dy) {
    final i = _indexOf(id);
    if (i < 0) return;
    final t = _texts[i];
    var x = t.x, y = t.y, w = t.width, h = t.height;

    if (fx != 0) {
      final avail = fx < 0 ? t.x + t.width : pageSize.width - t.x;
      w = _bound(t.width + fx * dx, math.min(minWidth, avail), avail);
      if (fx < 0) x = t.x + t.width - w;
    }
    if (fy != 0) {
      final avail = fy < 0 ? t.y + t.height : pageSize.height - t.y;
      h = _bound(t.height + fy * dy, math.min(minHeight, avail), avail);
      if (fy < 0) y = t.y + t.height - h;
    }
    if (w == t.width && h == t.height) return;

    _texts[i] = t.copyWith(x: x, y: y, width: w, height: h);
    _markChanged();
  }

  void setStyle(
    String id, {
    double? fontSize,
    int? colorValue,
    int? align,
    required double neededHeight,
  }) {
    final i = _indexOf(id);
    if (i < 0) return;
    final t = _texts[i];
    final h = _bound(
      math.max(t.height, neededHeight),
      minHeight,
      pageSize.height - t.y,
    );
    _texts[i] = t.copyWith(
      fontSize: fontSize,
      colorValue: colorValue,
      align: align,
      height: h,
    );
    _markChanged();
  }

  void deleteSelected() {
    final i = _indexOf(_selectedId);
    if (i < 0) return;
    _texts.removeAt(i);
    _selectedId = null;
    _editingId = null;
    _interacting = false;
    _markChanged();
  }

  // ---- Hit testing (paper units) ----

  PageText? textAt(Offset p) {
    for (var i = _texts.length - 1; i >= 0; i--) {
      if (_rect(_texts[i]).contains(p)) return _texts[i];
    }
    return null;
  }

  bool hitsSelectedChrome(Offset p) {
    final i = _indexOf(_selectedId);
    return i >= 0 && _rect(_texts[i]).inflate(handleReach).contains(p);
  }

  bool hitsToolbar(Offset p) => toolbarRect?.contains(p) ?? false;

  /// True when a pointer-down at [p] belongs to a text box, not to drawing.
  bool claims(Offset p, {required bool selectToolActive}) =>
      hitsToolbar(p) ||
      hitsSelectedChrome(p) ||
      (selectToolActive && textAt(p) != null);

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
    final snapshot = [
      for (final t in _texts)
        if (t.text.trim().isNotEmpty) t,
    ];
    final index = pageIndex;
    return _tail = _tail.then((_) => _write(snapshot, index));
  }

  Future<void> _write(List<PageText> snapshot, int index) async {
    try {
      await _repository.saveTexts(notebookId, snapshot, pageIndex: index);
    } catch (error, stack) {
      developer.log(
        'Saving page texts failed',
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

  void _dropIfEmpty(String? id) {
    final i = _indexOf(id);
    if (i < 0 || _texts[i].text.trim().isNotEmpty) return;
    _texts.removeAt(i);
    _markChanged();
  }

  int _indexOf(String? id) =>
      id == null ? -1 : _texts.indexWhere((t) => t.id == id);

  Rect _rect(PageText t) => Rect.fromLTWH(t.x, t.y, t.width, t.height);

  static double _bound(double v, double lo, double hi) =>
      hi < lo ? lo : v.clamp(lo, hi).toDouble();

  PageText _normalized(PageText t) {
    final w = math.min(t.width, pageSize.width);
    final h = math.min(t.height, pageSize.height);
    return PageText(
      id: t.id,
      text: t.text,
      x: _bound(t.x, 0, pageSize.width - w),
      y: _bound(t.y, 0, pageSize.height - h),
      width: w,
      height: h,
      colorValue: t.colorValue,
      fontSize: t.fontSize,
      align: t.align,
    );
  }
}
