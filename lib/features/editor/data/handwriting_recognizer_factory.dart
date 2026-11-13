import 'dart:io';

import '../domain/handwriting_recognizer.dart';
import 'mlkit_handwriting_recognizer.dart';

HandwritingRecognizer createHandwritingRecognizer() =>
    (Platform.isAndroid || Platform.isIOS)
    ? MlKitHandwritingRecognizer()
    : const UnsupportedHandwritingRecognizer();
