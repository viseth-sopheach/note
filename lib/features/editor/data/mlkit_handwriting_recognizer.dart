import 'dart:async';

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as ink;

import '../domain/handwriting_language.dart';
import '../domain/handwriting_recognizer.dart';
import '../domain/ink_normalizer.dart';
import '../domain/stroke.dart';

class _Scored {
  const _Scored(this.value, this.score);

  final RecognizedText value;
  final double score;
}

/// On-device recognition (Android and iOS). Each language model is
/// downloaded once, so the first conversion needs internet.
/// Recognition calls run one at a time (shared by every page); model
/// downloads are shared, de-duplicated and rate limited after a failure.
class MlKitHandwritingRecognizer implements HandwritingRecognizer {
  static const String _english = 'en-US';
  static const String _khmer = 'km';
  static const Duration _retryAfter = Duration(seconds: 30);

  final ink.DigitalInkRecognizerModelManager _models =
      ink.DigitalInkRecognizerModelManager();
  final Map<String, ink.DigitalInkRecognizer> _engines = {};
  final Set<String> _ready = {};
  final Map<String, Future<bool>> _downloads = {};
  final Map<String, DateTime> _failedAt = {};
  Future<void> _lock = Future<void>.value();

  @override
  bool get isSupported => true;

  Future<T> _exclusive<T>(Future<T> Function() body) {
    final done = Completer<void>();
    final prev = _lock;
    _lock = done.future;
    return prev.then((_) => body()).whenComplete(done.complete);
  }

  @override
  Future<RecognizedText?> recognize(
    List<Stroke> strokes, {
    required HandwritingLanguage language,
  }) => _exclusive(() => _recognize(strokes, language));

  Future<RecognizedText?> _recognize(
    List<Stroke> strokes,
    HandwritingLanguage language,
  ) async {
    final data = _toInk(strokes);
    final pointCount = data.strokes.fold<int>(0, (n, s) => n + s.points.length);
    if (pointCount < 2) return null;

    switch (language) {
      case HandwritingLanguage.english:
        return (await _run(_english, HandwritingLanguage.english, data))?.value;
      case HandwritingLanguage.khmer:
        return (await _run(_khmer, HandwritingLanguage.khmer, data))?.value;
      case HandwritingLanguage.auto:
        return _recognizeAuto(data);
    }
  }

  Future<RecognizedText?> _recognizeAuto(ink.Ink data) async {
    const models = [
      (_english, HandwritingLanguage.english),
      (_khmer, HandwritingLanguage.khmer),
    ];

    // Never wait for a download when another model is already usable;
    // fetch the missing one in the background instead.
    final ready = <(String, HandwritingLanguage)>[];
    for (final m in models) {
      if (await _isDownloaded(m.$1)) {
        ready.add(m);
      } else {
        unawaited(_ensureModel(m.$1));
      }
    }

    _Scored? best;
    var ok = 0;
    HandwritingModelException? modelError;
    for (final (code, lang) in ready.isEmpty ? models : ready) {
      try {
        final r = await _run(code, lang, data);
        ok++;
        // ML Kit ranks lower scores as better. Scores from different models
        // may not be strictly comparable: pick the language explicitly in
        // Settings for the most reliable results.
        if (r != null && (best == null || r.score < best.score)) best = r;
      } on HandwritingModelException catch (e) {
        modelError ??= e;
      } catch (_) {}
    }
    if (ok == 0) {
      throw modelError ??
          StateError('No handwriting language model is available.');
    }
    return best?.value;
  }

  Future<_Scored?> _run(
    String code,
    HandwritingLanguage lang,
    ink.Ink data,
  ) async {
    if (!await _ensureModel(code)) {
      final name = lang == HandwritingLanguage.khmer ? 'Khmer' : 'English';
      throw HandwritingModelException(
        lang,
        'The $name handwriting model is not ready. '
        'Connect to the internet once so it can download, then try again.',
      );
    }
    final engine = _engines.putIfAbsent(
      code,
      () => ink.DigitalInkRecognizer(languageCode: code),
    );
    try {
      final candidates = await engine
          .recognize(data)
          .timeout(const Duration(seconds: 20));
      if (candidates.isEmpty) return null;
      final best = candidates.first;
      return _Scored(RecognizedText(best.text, lang), best.score);
    } catch (_) {
      _engines.remove(code);
      try {
        await engine.close();
      } catch (_) {}
      rethrow;
    }
  }

  Future<bool> _isDownloaded(String code) async {
    if (_ready.contains(code)) return true;
    try {
      final ok = await _models
          .isModelDownloaded(code)
          .timeout(const Duration(seconds: 10));
      if (ok) _ready.add(code);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Shared per model: concurrent callers wait for the same download, and a
  /// failed download is not retried for [_retryAfter].
  Future<bool> _ensureModel(String code) {
    if (_ready.contains(code)) return Future<bool>.value(true);
    final failed = _failedAt[code];
    if (failed != null && DateTime.now().difference(failed) < _retryAfter) {
      return Future<bool>.value(false);
    }
    return _downloads.putIfAbsent(
      code,
      () => _download(code).whenComplete(() => _downloads.remove(code)),
    );
  }

  Future<bool> _download(String code) async {
    try {
      if (!await _isDownloaded(code)) {
        final ok = await _models
            .downloadModel(code, isWifiRequired: false)
            .timeout(const Duration(minutes: 2));
        if (!ok) {
          _failedAt[code] = DateTime.now();
          return false;
        }
      }
      _ready.add(code);
      _failedAt.remove(code);
      return true;
    } catch (_) {
      _failedAt[code] = DateTime.now();
      return false;
    }
  }

  ink.Ink _toInk(List<Stroke> strokes) {
    final data = ink.Ink();
    for (final points in InkNormalizer.normalize(strokes)) {
      final out = ink.Stroke();
      for (final p in points) {
        out.points.add(ink.StrokePoint(x: p.x, y: p.y, t: p.t));
      }
      data.strokes.add(out);
    }
    return data;
  }

  @override
  Future<void> dispose() async {
    await _exclusive(() async {
      for (final e in _engines.values) {
        try {
          await e.close();
        } catch (_) {}
      }
      _engines.clear();
    });
  }
}
