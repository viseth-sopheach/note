import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../domain/handwriting_language.dart';
import '../domain/handwriting_recognizer.dart';
import '../domain/page_text.dart';
import '../domain/stroke.dart';
import '../domain/stroke_grouper.dart';
import '../domain/stroke_selection.dart';
import '../domain/stroke_tool.dart';
import 'drawing_controller.dart';
import 'page_texts_controller.dart';

typedef TextMeasurer = ({double width, double height}) Function(
  String text,
  double fontSize,
);

typedef _Recognized = ({List<Stroke> strokes, String text});

/// Auto Alphabet Pen: [idleDelay] after the pen is lifted (plus
/// [khmerExtraDelay] for Khmer, whose vowels and subscripts are drawn as
/// separate strokes), the ink is split into spatial groups, each group is
/// recognized, and the whole batch is replaced by handwriting-font text
/// boxes. One undo step restores all the ink and removes all the text.
class AutoAlphabetController {
  AutoAlphabetController({
    required this.drawing,
    required this.texts,
    required this.recognizer,
    required this.language,
    required this.measure,
    this.onMessage,
    this.idleDelay = const Duration(milliseconds: 700),
    this.khmerExtraDelay = const Duration(milliseconds: 100),
    String Function()? idGenerator,
  }) : _newId = idGenerator ?? (() => const Uuid().v4()) {
    drawing.onStrokeBegan = _onBegan;
    drawing.onStrokeCommitted = _onCommitted;
  }

  /// Tune if the converted text looks too small or large against the ink.
  static const double fontScale = 1.15;
  static const double minFont = 18;
  static const double maxFont = 64;

  final DrawingController drawing;
  final PageTextsController texts;
  final HandwritingRecognizer recognizer;
  final HandwritingLanguage Function() language;
  final TextMeasurer measure;
  final void Function(String message)? onMessage;
  final Duration idleDelay;
  final Duration khmerExtraDelay;
  final String Function() _newId;

  final List<String> _pending = [];
  Timer? _timer;
  int _token = 0;
  bool _disposed = false;
  bool _warnedUnsupported = false;
  bool _running = false;
  bool _rerun = false;

  Duration get _delay => language() == HandwritingLanguage.khmer
      ? idleDelay + khmerExtraDelay
      : idleDelay;

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_delay, () => unawaited(_flush()));
  }

  void _onBegan() {
    if (drawing.tool != StrokeTool.autoPen) return;
    _timer?.cancel();
    _timer = null;
    _token++; // a result that is still being computed becomes stale
  }

  void _onCommitted(Stroke stroke) {
    if (stroke.tool != StrokeTool.autoPen || stroke.shape != null) return;
    _pending.add(stroke.id);
    _schedule();
  }

  Future<void> _flush() async {
    _timer = null;
    if (_disposed) return;
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    try {
      await _flushOnce();
    } catch (error, stack) {
      developer.log(
        'Auto Alphabet Pen failed',
        name: 'editor',
        error: error,
        stackTrace: stack,
      );
      _pending.clear();
    } finally {
      _running = false;
      final again = _rerun;
      _rerun = false;
      if (again && !_disposed && _pending.isNotEmpty && _timer == null) {
        _schedule();
      }
    }
  }

  Future<void> _flushOnce() async {
    final token = _token;

    final alive = {for (final s in drawing.strokes) s.id: s};
    final strokes = [
      for (final id in _pending)
        if (alive[id] != null) alive[id]!,
    ];
    _pending
      ..clear()
      ..addAll(strokes.map((s) => s.id));
    if (strokes.isEmpty) return;

    if (drawing.isDrawing) {
      _rerun = true; // retry when the pen is up
      return;
    }

    if (!recognizer.isSupported) {
      _pending.clear();
      if (!_warnedUnsupported) {
        _warnedUnsupported = true;
        onMessage?.call('Auto Alphabet Pen needs Android or iOS.');
      }
      return;
    }

    final recognized = <_Recognized>[];
    String? failure;
    for (final group in StrokeGrouper.group(strokes)) {
      RecognizedText? result;
      try {
        result = await recognizer.recognize(group, language: language());
      } catch (error, stack) {
        developer.log(
          'Handwriting recognition failed',
          name: 'editor',
          error: error,
          stackTrace: stack,
        );
        failure = error is HandwritingModelException
            ? error.message
            : 'Could not recognize handwriting.';
        break;
      }
      if (_disposed) return;
      if (token != _token || drawing.isDrawing) {
        _rerun = true; // the user kept writing: redo with all strokes
        return;
      }
      final text = result?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      if (text.isNotEmpty) recognized.add((strokes: group, text: text));
    }

    if (recognized.isNotEmpty) _convert(recognized);
    if (failure != null) onMessage?.call(failure);
    // Anything not converted stays as ink, exactly as written.
    _pending.clear();
  }

  PageText _boxFor(_Recognized g) {
    final b = StrokeSelection.pointBoundsOf(g.strokes)!;
    final inkW = b.right - b.left;
    final inkH = b.bottom - b.top;

    var font = inkH * fontScale;
    final unit = measure(g.text, 100).width / 100; // width per font unit
    if (unit > 0 && inkW > 0) font = math.min(font, inkW / unit);
    font = font.clamp(minFont, maxFont).toDouble();

    final m = measure(g.text, font);
    const inner = PageTextsController.innerPadding;
    final w = m.width + inner * 2 + 6;
    final h = m.height + inner * 2;
    final cy = (b.top + b.bottom) / 2;

    return PageText(
      id: _newId(),
      text: g.text,
      x: b.left - inner,
      y: cy - h / 2,
      width: w,
      height: h,
      colorValue: g.strokes.last.colorValue,
      fontSize: font,
      handwriting: true,
    );
  }

  /// All groups are swapped in one undo step.
  void _convert(List<_Recognized> groups) {
    final boxes = [for (final g in groups) _boxFor(g)];
    final ids = {
      for (final g in groups)
        for (final s in g.strokes) s.id,
    };

    final done = drawing.replaceWithSideEffect(
      ids,
      onApply: () {
        for (final box in boxes) {
          texts.insert(box);
        }
      },
      onRevert: () {
        for (final box in boxes) {
          texts.removeById(box.id);
        }
      },
    );
    if (done) _pending.clear();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (drawing.onStrokeBegan == _onBegan) drawing.onStrokeBegan = null;
    if (drawing.onStrokeCommitted == _onCommitted) {
      drawing.onStrokeCommitted = null;
    }
  }
}
