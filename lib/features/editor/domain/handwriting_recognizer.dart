import 'handwriting_language.dart';
import 'stroke.dart';

final class RecognizedText {
  const RecognizedText(this.text, this.language);

  final String text;
  final HandwritingLanguage language;
}

abstract interface class HandwritingRecognizer {
  bool get isSupported;

  /// Returns null when nothing was recognized. Throws when the engine or
  /// its language model is unavailable.
  Future<RecognizedText?> recognize(
    List<Stroke> strokes, {
    required HandwritingLanguage language,
  });

  Future<void> dispose();
}

/// Used on platforms without an on-device engine (Windows).
final class UnsupportedHandwritingRecognizer implements HandwritingRecognizer {
  const UnsupportedHandwritingRecognizer();

  @override
  bool get isSupported => false;

  @override
  Future<RecognizedText?> recognize(
    List<Stroke> strokes, {
    required HandwritingLanguage language,
  }) async => null;

  @override
  Future<void> dispose() async {}
}
