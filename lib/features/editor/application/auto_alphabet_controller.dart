import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../domain/handwriting_language.dart';
import '../domain/handwriting_recognizer.dart';
import '../domain/page_text.dart';
import '../domain/stroke.dart';
import '../domain/stroke_selection.dart';
import '../domain/stroke_tool.dart';
import 'drawing_controller.dart';
import 'page_texts_controller.dart';

typedef TextMeasurer = ({double width, double height}) Function(
  String text,
  double fontSize,
);

/// Auto Alphabet Pen: [idleDelay] after the pen is lifted, the ink written
/// with the Auto Alphabet Pen is recognized and replaced by a handwriting
/// font text box. One undo step restores the ink and removes the text.
class AutoAlphabetController {
  AutoAlphabetController({
    required this.drawing,
    required this.texts,
    required this.recognizer,
    required this.language,
    required this.measure,
    this.onMessage,
    this.idleDelay = const Duration(milliseconds: 600),
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
  final String Function() _newId;

  final List<String> _pending = [];
  Timer? _timer;
  int _token = 0;
  bool _disposed = false;
  bool _warnedUnsupported = false;
  bool _running = false;
  bool _rerun = false;

  void _onBegan() {
    if (drawing.tool != StrokeTool.autoPen) return;
    _timer?.cancel();
    _timer = null;
    _token++; // a result that is still being computed becomes stale
  }

  void _onCommitted(Stroke stroke) {
    if (stroke.tool != StrokeTool.autoPen || stroke.shape != null) return;
    _pending.add(stroke.id);
    _timer?.cancel();
    _timer = Timer(idleDelay, () => unawaited(_flush()));
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
        _timer = Timer(idleDelay, () => unawaited(_flush()));
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

    RecognizedText? result;
    try {
      result = await recognizer.recognize(strokes, language: language());
    } catch (error, stack) {
      developer.log(
        'Handwriting recognition failed',
        name: 'editor',
        error: error,
        stackTrace: stack,
      );
      _pending.clear();
      onMessage?.call(
        'Could not recognize handwriting. The language model needs internet once.',
      );
      return;
    }
    if (_disposed || token != _token) return; // the user kept writing
    if (drawing.isDrawing) {
      _rerun = true;
      return;
    }

    final text = result?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (text.isEmpty) {
      _pending.clear(); // keep the ink as written
      return;
    }
    _convert(strokes, text);
  }

  void _convert(List<Stroke> strokes, String text) {
    final b = StrokeSelection.pointBoundsOf(strokes);
    if (b == null) return;

    final fontSize = ((b.bottom - b.top) * fontScale).clamp(minFont, maxFont);
    final m = measure(text, fontSize);
    const inner = PageTextsController.innerPadding;
    final w = m.width + inner * 2 + 6;
    final h = m.height + inner * 2;
    final cy = (b.top + b.bottom) / 2;

    final box = PageText(
      id: _newId(),
      text: text,
      x: b.left - inner,
      y: cy - h / 2,
      width: w,
      height: h,
      colorValue: strokes.last.colorValue,
      fontSize: fontSize.toDouble(),
      handwriting: true,
    );

    final done = drawing.replaceWithSideEffect(
      {for (final s in strokes) s.id},
      onApply: () => texts.insert(box),
      onRevert: () => texts.removeById(box.id),
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
