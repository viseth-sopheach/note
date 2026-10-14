import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/library_providers.dart';
import '../../library/domain/paper_template.dart';
import '../../library/presentation/dialogs/confirm_delete_dialog.dart';
import '../application/autosave_controller.dart';
import '../application/drawing_controller.dart';
import '../application/editor_providers.dart';
import '../application/tool_settings.dart';
import '../domain/page_repository.dart';
import 'dialogs/paper_template_dialog.dart';
import 'drawing/drawing_surface.dart';
import 'drawing/ink_layers.dart';
import 'drawing/selection_layer.dart';
import 'paper/paper_painter.dart';
import 'paper/paper_view.dart';
import 'toolbar/drawing_toolbar.dart';
import 'toolbar/page_bar.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key, required this.notebookId});

  final String notebookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebook = ref.watch(notebookProvider(notebookId));

    return Scaffold(
      appBar: AppBar(title: Text(notebook.value?.title ?? 'Notebook')),
      body: notebook.when(
        data: (value) {
          if (value == null) {
            return const Center(child: Text('Notebook not found'));
          }
          return _EditorCanvas(
            notebookId: notebookId,
            template: value.template,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not open this notebook.')),
      ),
    );
  }
}

class _PageSession {
  _PageSession({
    required this.index,
    required this.controller,
    required this.template,
    required this.autosave,
  });

  /// Changes when pages before this one are added or deleted.
  int index;
  final DrawingController controller;
  final PaperTemplate template;
  AutosaveController autosave;

  void close() {
    unawaited(autosave.dispose());
    controller.dispose();
  }
}

class _EditorCanvas extends ConsumerStatefulWidget {
  const _EditorCanvas({required this.notebookId, required this.template});

  final String notebookId;

  /// Template used by pages that have no template of their own.
  final PaperTemplate template;

  @override
  ConsumerState<_EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<_EditorCanvas>
    with WidgetsBindingObserver {
  static const double _pad = 24;
  static const double _gap = 16;
  static const double _margin = 48;

  static double get _contentWidth => kPageSize.width + _pad * 2;

  final ToolSettings _settings = ToolSettings();
  final TransformationController _transform = TransformationController();
  final List<_PageSession> _sessions = [];
  late final PageRepository _repository;

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  bool _fitted = false;
  int _activeIndex = 0;
  double _viewportW = 600;
  double _viewportH = 600;

  /// Phones and tablets usually have no stylus, so a finger draws by default.
  bool _fingerDraws = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  DrawingController get _active => _sessions[_activeIndex].controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transform.addListener(_keepCentered);
    _repository = ref.read(pageRepositoryProvider);
    unawaited(_load());
  }

  AutosaveController _newAutosave(DrawingController controller, int index) {
    return AutosaveController(
      controller: controller,
      repository: _repository,
      notebookId: widget.notebookId,
      pageIndex: index,
    );
  }

  Future<_PageSession> _openPage(int index) async {
    final strokes = await _repository.loadStrokes(
      widget.notebookId,
      pageIndex: index,
    );
    final template = await _repository.loadTemplate(
          widget.notebookId,
          pageIndex: index,
        ) ??
        widget.template;
    final controller = DrawingController(settings: _settings);
    controller.replaceStrokes(strokes);
    return _PageSession(
      index: index,
      controller: controller,
      template: template,
      autosave: _newAutosave(controller, index),
    );
  }

  Future<void> _load() async {
    final opened = <_PageSession>[];
    try {
      final count = math.max(1, await _repository.pageCount(widget.notebookId));
      for (var i = 0; i < count; i++) {
        opened.add(await _openPage(i));
      }
      if (!mounted) {
        for (final s in opened) {
          s.close();
        }
        return;
      }
      setState(() {
        _sessions
          ..clear()
          ..addAll(opened);
        _activeIndex = 0;
        _loading = false;
      });
    } catch (error, stack) {
      developer.log(
        'Failed to load pages',
        name: 'editor',
        error: error,
        stackTrace: stack,
      );
      for (final s in opened) {
        s.close();
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    unawaited(_load());
  }

  // ---- Page actions ----

  /// Runs a page change while input and page buttons are disabled.
  Future<void> _runExclusive(
    String failureMessage,
    Future<void> Function() body,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } catch (error, stack) {
      developer.log(
        failureMessage,
        name: 'editor',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves every page. Returns false when something could not be saved.
  Future<bool> _flushAll() async {
    await Future.wait([for (final s in _sessions) s.autosave.flush()]);
    return _sessions.every((s) => !s.autosave.hasUnsavedChanges);
  }

  /// Points the page at a new index and restarts its autosave there.
  Future<void> _rebind(_PageSession session, int index) async {
    if (session.index == index) return;
    await session.autosave.dispose();
    session.index = index;
    session.autosave = _newAutosave(session.controller, index);
  }

  void _scheduleScroll(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToPage(index);
    });
  }

  Future<void> _addPage() async {
    if (_busy || _sessions.isEmpty) return;
    final template = await PaperTemplateDialog.show(
      context,
      title: 'Add page',
      confirmLabel: 'Add',
      initial: _sessions[_visiblePage].template,
    );
    if (template == null || !mounted) return;

    await _runExclusive('Could not add a page.', () async {
      final index = _sessions.length;
      await _repository.insertPage(
        widget.notebookId,
        pageIndex: index,
        template: template,
      );
      final session = await _openPage(index);
      if (!mounted) {
        session.close();
        return;
      }
      setState(() {
        _sessions.add(session);
        _activeIndex = index;
      });
      _scheduleScroll(index);
    });
  }

  Future<void> _duplicatePage() async {
    if (_busy || _sessions.isEmpty) return;
    final index = _visiblePage;
    final source = _sessions[index];

    await _runExclusive('Could not duplicate the page.', () async {
      if (!await _flushAll()) {
        throw StateError('Unsaved changes could not be saved.');
      }
      final target = index + 1;
      await _repository.insertPage(
        widget.notebookId,
        pageIndex: target,
        template: source.template,
        strokes: source.controller.strokes,
      );
      final copy = await _openPage(target);
      final updated = [..._sessions]..insert(target, copy);
      for (var i = target + 1; i < updated.length; i++) {
        await _rebind(updated[i], i);
      }
      if (!mounted) {
        copy.close();
        return;
      }
      setState(() {
        _sessions
          ..clear()
          ..addAll(updated);
        _activeIndex = target;
      });
      _scheduleScroll(target);
    });
  }

  Future<void> _deletePage() async {
    if (_busy || _sessions.length < 2) return;
    final index = _visiblePage;
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete page?',
      message:
          'Page ${index + 1} of ${_sessions.length} will be deleted. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;

    await _runExclusive('Could not delete the page.', () async {
      if (!await _flushAll()) {
        throw StateError('Unsaved changes could not be saved.');
      }
      await _repository.deletePage(widget.notebookId, index);
      final removed = _sessions[index];
      final remaining = [..._sessions]..removeAt(index);
      for (var i = index; i < remaining.length; i++) {
        await _rebind(remaining[i], i);
      }
      if (!mounted) return;
      final next = math.min(index, remaining.length - 1);
      setState(() {
        _sessions
          ..clear()
          ..addAll(remaining);
        _activeIndex = next;
      });
      // Disposed after the frame so no widget uses the controller anymore.
      WidgetsBinding.instance.addPostFrameCallback((_) => removed.close());
      _scheduleScroll(next);
    });
  }

  // ---- Scrolling, zooming, centering ----

  double _pageTop(int index) => _pad + index * (kPageSize.height + _gap);

  double get _contentHeight =>
      _pad * 2 +
      _sessions.length * kPageSize.height +
      (_sessions.length - 1) * _gap;

  double _clampTy(double ty, double scale) {
    final lowest = math.min(_margin, _viewportH - _contentHeight * scale - _margin);
    return ty.clamp(lowest, _margin).toDouble();
  }

  void _setTransform(double scale, double tx, double ty) {
    _transform.value = Matrix4(
      scale, 0, 0, 0, //
      0, scale, 0, 0, //
      0, 0, 1, 0, //
      tx, ty, 0, 1,
    );
  }

  /// Keeps the pages horizontally centered at every zoom level. When the
  /// pages are wider than the viewport, panning is limited to their edges.
  void _keepCentered() {
    if (_sessions.isEmpty) return;
    final m = _transform.value;
    final scale = m.storage[0];
    final tx = m.storage[12];
    final scaledWidth = _contentWidth * scale;

    final double target;
    if (scaledWidth <= _viewportW) {
      target = (_viewportW - scaledWidth) / 2;
    } else {
      target = tx.clamp(_viewportW - scaledWidth - _margin, _margin).toDouble();
    }
    if ((target - tx).abs() < 0.5) return;
    _setTransform(scale, target, m.storage[13]);
  }

  /// First layout: fit narrow screens to the page width, never above 100%.
  void _fitWidth() {
    final scale = math.min(1.0, _viewportW / _contentWidth).clamp(0.25, 1.0);
    _fitted = true;
    _setTransform(scale.toDouble(), 0, 0);
  }

  int get _visiblePage {
    final scale = _transform.value.storage[0];
    final ty = _transform.value.storage[13];
    final sceneY = (_viewportH / 2 - ty) / scale;
    final i = ((sceneY - _pad) / (kPageSize.height + _gap)).floor();
    return i.clamp(0, _sessions.length - 1);
  }

  void _scrollToPage(int index) {
    if (index < 0 || index >= _sessions.length) return;
    final m = _transform.value;
    final scale = m.storage[0];
    final ty = _clampTy(-_pageTop(index) * scale + _pad, scale);
    _setTransform(scale, m.storage[12], ty);
    _setActive(index);
  }

  void _setActive(int index) {
    if (index == _activeIndex || index < 0 || index >= _sessions.length) {
      return;
    }
    _active.clearSelection();
    setState(() => _activeIndex = index);
  }

  /// Mouse wheel scrolls the pages; Ctrl + wheel zooms.
  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (HardwareKeyboard.instance.isControlPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final scroll = e as PointerScrollEvent;
      final m = _transform.value;
      final scale = m.storage[0];
      final ty = _clampTy(m.storage[13] - scroll.scrollDelta.dy, scale);
      _setTransform(scale, m.storage[12], ty);
    });
  }

  // ---- Lifecycle ----

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    for (final s in _sessions) {
      unawaited(s.autosave.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transform.removeListener(_keepCentered);
    for (final s in _sessions) {
      s.close();
    }
    _settings.dispose();
    _transform.dispose();
    super.dispose();
  }

  // ---- UI ----

  Widget _buildPage(_PageSession session) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setActive(session.index),
      child: DrawingSurface(
        controller: session.controller,
        allowTouch: _fingerDraws,
        child: Stack(
          children: [
            PaperView(template: session.template),
            Positioned.fill(
              child: CommittedInkLayer(controller: session.controller),
            ),
            Positioned.fill(
              child: LiveInkLayer(controller: session.controller),
            ),
            Positioned.fill(
              child: SelectionLayer(controller: session.controller),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load this notebook\'s pages.'),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;

    final pages = Padding(
      padding: const EdgeInsets.all(_pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _gap,
        children: [for (final s in _sessions) _buildPage(s)],
      ),
    );

    final anyDrawing =
        Listenable.merge([for (final s in _sessions) s.controller]);

    final editor = Column(
      children: [
        DrawingToolbar(
          controller: _active,
          fingerDraws: _fingerDraws,
          onFingerDrawsChanged: (value) =>
              setState(() => _fingerDraws = value),
        ),
        SizedBox(
          height: 2,
          child: _busy ? const LinearProgressIndicator() : null,
        ),
        Expanded(
          child: AbsorbPointer(
            absorbing: _busy,
            child: ColoredBox(
              color: colors.surfaceContainerHighest,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewportH = constraints.maxHeight;
                  final widthChanged = constraints.maxWidth != _viewportW;
                  _viewportW = constraints.maxWidth;
                  if (widthChanged || !_fitted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      if (_fitted) {
                        _keepCentered();
                      } else {
                        _fitWidth();
                      }
                    });
                  }
                                    return Stack(
                    children: [
                      ListenableBuilder(
                        listenable: anyDrawing,
                        child: pages,
                        builder: (context, child) {
                          final drawing =
                              _sessions.any((s) => s.controller.isDrawing);
                          return InteractiveViewer(
                            transformationController: _transform,
                            constrained: false,
                            minScale: 0.25,
                            maxScale: 4,
                            boundaryMargin: const EdgeInsets.all(_margin),
                            panEnabled: !drawing,
                            scaleEnabled: !drawing,
                            child: child!,
                          );
                        },
                      ),
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerSignal: _onSignal,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _transform,
          builder: (context, _) => PageBar(
            pageIndex: _visiblePage,
            pageCount: _sessions.length,
            busy: _busy,
            onPrevious: () => _scrollToPage(_visiblePage - 1),
            onNext: () => _scrollToPage(_visiblePage + 1),
            onAdd: () => unawaited(_addPage()),
            onDuplicate: () => unawaited(_duplicatePage()),
            onDelete:
                _sessions.length > 1 ? () => unawaited(_deletePage()) : null,
          ),
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
            _active.undo(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
            _active.redo(),
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): () => _active.redo(),
        const SingleActivator(LogicalKeyboardKey.delete): () =>
            _active.deleteSelection(),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _active.clearSelection(),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            _scrollToPage(_visiblePage - 1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            _scrollToPage(_visiblePage + 1),
      },
      child: Focus(autofocus: true, child: editor),
    );
  }
}