import 'dart:async';
import 'dart:developer' as developer;

import '../domain/page_repository.dart';
import '../domain/stroke.dart';
import 'drawing_controller.dart';

/// Saves the strokes of one page shortly after they change.
class AutosaveController {
  AutosaveController({
    required this.controller,
    required this.repository,
    required this.notebookId,
    this.delay = const Duration(milliseconds: 800),
    this.retryDelay = const Duration(seconds: 5),
  }) : _savedRevision = controller.revision {
    controller.addListener(_onChanged);
  }

  final DrawingController controller;
  final PageRepository repository;
  final String notebookId;
  final Duration delay;
  final Duration retryDelay;

  Timer? _timer;
  int _savedRevision;
  bool _disposed = false;
  Future<void> _tail = Future<void>.value();

  bool get hasUnsavedChanges => controller.revision != _savedRevision;

  void _onChanged() {
    if (!hasUnsavedChanges) return;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  /// Saves now if there are unsaved changes. Saves never overlap.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (!hasUnsavedChanges) return _tail;

    final revision = controller.revision;
    final snapshot = List<Stroke>.of(controller.strokes);
    return _tail = _tail.then((_) => _write(revision, snapshot));
  }

  Future<void> _write(int revision, List<Stroke> snapshot) async {
    try {
      await repository.saveStrokes(notebookId, snapshot);
      if (revision > _savedRevision) _savedRevision = revision;
    } catch (error, stack) {
      developer.log(
        'Autosave failed',
        name: 'editor',
        error: error,
        stackTrace: stack,
      );
      if (!_disposed) {
        _timer?.cancel();
        _timer = Timer(retryDelay, () => unawaited(flush()));
      }
    }
  }

  /// Stops listening and saves any pending changes.
  Future<void> dispose() {
    controller.removeListener(_onChanged);
    _disposed = true;
    return flush();
  }
}