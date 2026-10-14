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
import '../application/autosave_controller.dart';
import '../application/drawing_controller.dart';
import '../application/editor_providers.dart';
import '../application/tool_settings.dart';
import '../domain/page_repository.dart';
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
  _PageSession(this.index, this.controller);

  final int index;
  final DrawingController controller;
  AutosaveController? autosave;

  void close() {
    final a = autosave;
    if (a != null) unawaited(a.dispose());
    controller.dispose();
  }
}

class _EditorCanvas extends ConsumerStatefulWidget {
  const _EditorCanvas({required this.notebookId, required this.template});

  final String notebookId;
  final PaperTemplate template;

  @override
  ConsumerState<_EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<_EditorCanvas>
    with WidgetsBindingObserver {
  static const double _pad = 24;
  static const double _gap = 16;
  static const double _margin = 48;

  final ToolSettings _settings = ToolSettings();
  final TransformationController _transform = TransformationController();
  final List<_PageSession> _sessions = [];
  late final PageRepository _repository;

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  int _activeIndex = 0;
  double _viewportH = 600;

  /// Phones and tablets usually have no stylus, so a finger draws by default.
  bool _fingerDraws = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  DrawingController get _active => _sessions[_activeIndex].controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = ref.read(pageRepositoryProvider);
    unawaited(_load());
  }

  Future<_PageSession> _openPage(int index) async {
    final strokes = await _repository.loadStrokes(
      widget.notebookId,
      pageIndex: index,
    );
    final controller = DrawingController(settings: _settings);
    controller.replaceStrokes(strokes);
    final session = _PageSession(index, controller);
    session.autosave = AutosaveController(
      controller: controller,
      repository: _repository,
      notebookId: widget.notebookId,
      pageIndex: index,
    );
    return session;
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

  Future<void> _addPage() async {
    if (_busy) return;
    _busy = true;
    try {
      final index = _sessions.length;
      await _repository.saveStrokes(
        widget.notebookId,
        const [],
        pageIndex: index,
      );
      final session = await _openPage(index);
      if (!mounted) {
        session.close();
        return;
      }
      setState(() => _sessions.add(session));
      _setActive(index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToPage(index);
      });
    } catch (error, stack) {
      developer.log(
        'Failed to add page',
        name: 'editor',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not add a page.')),
          );
      }
    } finally {
      _busy = false;
    }
  }

  // ---- Scrolling ----

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
      final a = s.autosave;
      if (a != null) unawaited(a.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            PaperView(template: widget.template),
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

    final pages = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _onSignal,
      child: Padding(
        padding: const EdgeInsets.all(_pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: _gap,
          children: [for (final s in _sessions) _buildPage(s)],
        ),
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
        Expanded(
          child: ColoredBox(
            color: colors.surfaceContainerHighest,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportH = constraints.maxHeight;
                return ListenableBuilder(
                  listenable: anyDrawing,
                  child: pages,
                  builder: (context, child) {
                    final drawing = _sessions.any((s) => s.controller.isDrawing);
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
                );
              },
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _transform,
          builder: (context, _) => PageBar(
            pageIndex: _visiblePage,
            pageCount: _sessions.length,
            onPrevious: () => _scrollToPage(_visiblePage - 1),
            onNext: () => _scrollToPage(_visiblePage + 1),
            onAdd: () => unawaited(_addPage()),
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