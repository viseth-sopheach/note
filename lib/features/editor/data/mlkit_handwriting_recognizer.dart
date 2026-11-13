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
class MlKitHandwritingRecognizer implements HandwritingRecognizer {
  static const String _english = 'en-US';
  static const String _khmer = 'km';

  final ink.DigitalInkRecognizerModelManager _models =
      ink.DigitalInkRecognizerModelManager();
  final Map<String, ink.DigitalInkRecognizer> _engines = {};
  final Set<String> _ready = {};

  @override
  bool get isSupported => true;

  @override
  Future<RecognizedText?> recognize(
    List<Stroke> strokes, {
    required HandwritingLanguage language,
  }) async {
    final data = _toInk(strokes);
    switch (language) {
      case HandwritingLanguage.english:
        return (await _run(_english, HandwritingLanguage.english, data))?.value;
      case HandwritingLanguage.khmer:
        return (await _run(_khmer, HandwritingLanguage.khmer, data))?.value;
      case HandwritingLanguage.auto:
        final results = await Future.wait([
          _safe(_english, HandwritingLanguage.english, data),
          _safe(_khmer, HandwritingLanguage.khmer, data),
        ]);
        final found = [for (final r in results) ?r];
        if (found.isEmpty) {
          throw StateError('No handwriting language model is available.');
        }
        // Verify on a device: ML Kit ranks lower scores as better.
        found.sort((a, b) => a.score.compareTo(b.score));
        return found.first.value;
    }
  }

  Future<_Scored?> _safe(
    String code,
    HandwritingLanguage lang,
    ink.Ink data,
  ) async {
    try {
      return await _run(code, lang, data);
    } catch (_) {
      return null;
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
    final candidates = await engine.recognize(data);
    if (candidates.isEmpty) return null;
    final best = candidates.first;
    return _Scored(RecognizedText(best.text, lang), best.score);
  }

  Future<bool> _ensureModel(String code) async {
    if (_ready.contains(code)) return true;
    if (!await _models.isModelDownloaded(code)) {
      if (!await _models.downloadModel(code, isWifiRequired: false)) {
        return false;
      }
    }
    _ready.add(code);
    return true;
  }

  ink.Ink _toInk(List<Stroke> strokes) {
    final data = ink.Ink();
    var base = 0;
    for (final s in strokes) {
      final out = ink.Stroke();
      var last = 0;
      for (final p in s.points) {
        out.points.add(
          ink.StrokePoint(x: p.x, y: p.y, t: base + p.timestampMs),
        );
        last = p.timestampMs;
      }
      base += last + 120;
      data.strokes.add(out);
    }
    return data;
  }

  @override
  Future<void> dispose() async {
    for (final e in _engines.values) {
      await e.close();
    }
    _engines.clear();
  }
}
