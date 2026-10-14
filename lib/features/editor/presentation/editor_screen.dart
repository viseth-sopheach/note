import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/library_providers.dart';
import '../../library/domain/paper_template.dart';
import '../application/autosave_controller.dart';
import '../application/drawing_controller.dart';
import '../application/editor_providers.dart';
import '../domain/page_repository.dart';
import 'drawing/drawing_surface.dart';
import 'drawing/ink_layers.dart';
import 'paper/paper_view.dart';
import 'toolbar/drawing_toolbar.dart';
import 'package:flutter/services.dart';

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

class _EditorCanvas extends ConsumerStatefulWidget {
  const _EditorCanvas({required this.notebookId, required this.template});

  final String notebookId;
  final PaperTemplate template;

  @override
  ConsumerState<_EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<_EditorCanvas>
    with WidgetsBindingObserver {
  final DrawingController _controller = DrawingController();
  late final PageRepository _repository;
  AutosaveController? _autosave;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = ref.read(pageRepositoryProvider);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final strokes = await _repository.loadStrokes(widget.notebookId);
      if (!mounted) return;
      _controller.replaceStrokes(strokes);
      _autosave = AutosaveController(
        controller: _controller,
        repository: _repository,
        notebookId: widget.notebookId,
      );
      setState(() => _loading = false);
    } catch (error, stack) {
      developer.log(
        'Failed to load page',
        name: 'editor',
        error: error,
        stackTrace: stack,
      );
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    final autosave = _autosave;
    if (autosave != null) unawaited(autosave.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final autosave = _autosave;
    if (autosave != null) unawaited(autosave.dispose());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load this notebook\'s page.'),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;

    final page = DrawingSurface(
      controller: _controller,
      child: Stack(
        children: [
          PaperView(template: widget.template),
          Positioned.fill(child: CommittedInkLayer(controller: _controller)),
          Positioned.fill(child: LiveInkLayer(controller: _controller)),
        ],
      ),
    );

    final editor = Column(
      children: [
        DrawingToolbar(controller: _controller),
        Expanded(
          child: ColoredBox(
            color: colors.surfaceContainerHighest,
            child: ListenableBuilder(
              listenable: _controller,
              child: page,
              builder: (context, child) => InteractiveViewer(
                constrained: false,
                minScale: 0.25,
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(48),
                panEnabled: !_controller.isDrawing,
                scaleEnabled: !_controller.isDrawing,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
        );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _controller.redo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _controller.redo,
      },
      child: Focus(autofocus: true, child: editor),
    );
  }
}