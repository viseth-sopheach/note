import 'dart:async';

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as ink;

import '../domain/handwriting_language.dart';
import '../domain/handwriting_recognizer.dart';
import '../domain/stroke.dart';

class _Scored {
  const _Scored(this.value, this.score);

  final RecognizedText value;
  final double score;
}

/// On-device recognition (Android and iOS). Each language model is
/// downloaded once, so the first conversion needs internet.
/// All native calls run one at a time (shared by every page).
class MlKitHandwritingRecognizer implements HandwritingRecognizer {
  static const String _english = 'en-US';
  static const String _khmer = 'km';

  final ink.DigitalInkRecognizerModelManager _models =
      ink.DigitalInkRecognizerModelManager();
  final Map<String, ink.DigitalInkRecognizer> _engines = {};
  final Set<String> _ready = {};
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
    if (data.strokes.isEmpty) return null;

    final pointCount = data.strokes.fold<int>(0, (n, s) => n + s.points.length);
    if (data.strokes.isEmpty || pointCount < 4) return null;

    switch (language) {
      case HandwritingLanguage.english:
        return (await _run(_english, HandwritingLanguage.english, data))?.value;
      case HandwritingLanguage.khmer:
        return (await _run(_khmer, HandwritingLanguage.khmer, data))?.value;
      case HandwritingLanguage.auto:
        _Scored? best;
        var ok = 0;
        final models = [
          (_english, HandwritingLanguage.english),
          (_khmer, HandwritingLanguage.khmer),
        ];
        for (final (code, lang) in models) {
          try {
            final r = await _run(code, lang, data);
            ok++;
            // Verify on a device: ML Kit ranks lower scores as better.
            if (r != null && (best == null || r.score < best.score)) best = r;
          } catch (_) {}
        }
        if (ok == 0) {
          throw StateError('No handwriting language model is available.');
        }
        return best?.value;
    }
  }

  Future<_Scored?> _run(
    String code,
    HandwritingLanguage lang,
    ink.Ink data,
  ) async {
    if (!await _ensureModel(code)) {
      throw StateError('Language model not available: $code');
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

  Future<bool> _ensureModel(String code) async {
    if (_ready.contains(code)) return true;
    try {
      if (!await _models
          .isModelDownloaded(code)
          .timeout(const Duration(seconds: 10))) {
        if (!await _models
            .downloadModel(code, isWifiRequired: false)
            .timeout(const Duration(minutes: 2))) {
          return false;
        }
      }
    } catch (_) {
      return false;
    }
    _ready.add(code);
    return true;
  }

  ink.Ink _toInk(List<Stroke> strokes) {
    final data = ink.Ink();
    var base = 0;
    for (final s in strokes) {
      final out = ink.Stroke();
      var last = base;
      for (final p in s.points) {
        if (!p.x.isFinite || !p.y.isFinite) continue;
        final t = (base + p.timestampMs) < last ? last : base + p.timestampMs;
        out.points.add(ink.StrokePoint(x: p.x, y: p.y, t: t));
        last = t;
      }
      if (out.points.isEmpty) continue;
      base = last + 120;
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
