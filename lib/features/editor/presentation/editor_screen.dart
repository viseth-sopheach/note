import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';

import '../../../app/routes.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/paper_template.dart';
import '../../library/presentation/dialogs/confirm_delete_dialog.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/domain/editor_position.dart';
import '../../settings/domain/settings_repository.dart';
import '../../sharing/application/sharing_providers.dart';
import '../application/autosave_controller.dart';
import '../application/drawing_controller.dart';
import '../application/editor_providers.dart';
import '../application/measure_controller.dart';
import '../application/tool_settings.dart';
import '../domain/page_repository.dart';
import 'dialogs/paper_template_dialog.dart';
import 'drawing/drawing_surface.dart';
import 'drawing/ink_layers.dart';
import 'drawing/selection_layer.dart';
import 'measure/measure_overlay.dart';
import 'paper/page_metrics.dart';
import 'paper/paper_painter.dart';
import 'paper/paper_view.dart';
import 'toolbar/floating_toolbar.dart';
import 'toolbar/page_bar.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.notebookId});

  final String notebookId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final GlobalKey<_EditorCanvasState> _canvasKey =
      GlobalKey<_EditorCanvasState>();

  @override
  Widget build(BuildContext context) {
    final notebook = ref.watch(notebookProvider(widget.notebookId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: notebook.when(
          data: (value) {
            if (value == null) {
              return const Center(child: Text('Notebook not found'));
            }
            return _EditorCanvas(
              key: _canvasKey,
              notebookId: widget.notebookId,
              template: value.template,
              title: value.title,
              folderId: value.folderId,
              pdfPath: value.pdfPath,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              const Center(child: Text('Could not open this notebook.')),
        ),
      ),
    );
  }
}

class _PageSession {
  _PageSession({
    required this.index,
    required this.controller,
    required this.template,
    required this.imagePath,
    required this.autosave,
  });

  /// Changes when pages before this one are added or deleted.
  int index;
  final DrawingController controller;
  final PaperTemplate template;
  final String? imagePath;
  AutosaveController autosave;

  void close() {
    unawaited(autosave.dispose());
    controller.dispose();
  }
}

class _EditorCanvas extends ConsumerStatefulWidget {
  const _EditorCanvas({
    super.key,
    required this.notebookId,
    required this.template,
    required this.title,
    this.folderId,
    this.pdfPath,
  });

  final String notebookId;
  final PaperTemplate template;
  final String title;
  final String? folderId;
  final String? pdfPath;

  @override
  ConsumerState<_EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<_EditorCanvas>
    with WidgetsBindingObserver {
  static const double _pad = 24;
  static const double _margin = 48;

  /// Width of the scrollable content: page cell (paper + drawable margin)
  /// plus padding.
  static double get _contentWidth => kCellSize.width + _pad * 2;

  static double get _cellH => kCellSize.height;

  late final ToolSettings _settings;
  late final SettingsRepository _settingsRepository;
  late final bool _rememberPosition;
  final MeasureController _measure = MeasureController();
  final TransformationController _transform = TransformationController();
  final List<_PageSession> _sessions = [];
  late final PageRepository _repository;

  PdfDocument? _pdf;

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  bool _fitted = false;
  int _activeIndex = 0;
  double _viewportW = 600;
  double _viewportH = 600;

  /// Phones and tablets usually have no stylus, so a finger draws by default.
  bool _fingerDraws =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  DrawingController get _active => _sessions[_activeIndex].controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transform.addListener(_keepCentered);
    _repository = ref.read(pageRepositoryProvider);
    _settingsRepository = ref.read(settingsRepositoryProvider);
    final saved = ref.read(appSettingsProvider);
    _rememberPosition = saved.rememberPosition;
    _settings = ToolSettings(
      tool: saved.defaultTool,
      penColorValue: saved.penColorValue,
      penWidth: saved.penWidth,
      highlighterColorValue: saved.highlighterColorValue,
      highlighterWidth: saved.highlighterWidth,
      shapeRecognition: saved.shapeRecognition,
    );
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

  /// Paper corner of a page in scene coordinates.
  Offset _paperOrigin(int index) =>
      Offset(_pad + kBleedX, _pad + index * _cellH + kBleedY);

  Future<_PageSession> _openPage(int index) async {
    final strokes = await _repository.loadStrokes(
      widget.notebookId,
      pageIndex: index,
    );
    final template =
        await _repository.loadTemplate(widget.notebookId, pageIndex: index) ??
        widget.template;
    final imagePath = await _repository.loadImagePath(
      widget.notebookId,
      pageIndex: index,
    );
    final controller = DrawingController(
      settings: _settings,
      undoLimit: ref.read(appSettingsProvider).undoLimit,
    );
    controller.replaceStrokes(strokes);
    controller.onShapeRecognized = () =>
        unawaited(HapticFeedback.selectionClick());
    final session = _PageSession(
      index: index,
      controller: controller,
      template: template,
      imagePath: imagePath,
      autosave: _newAutosave(controller, index),
    );
    controller.snapSegments = () =>
        _measure.edgesRelativeTo(_paperOrigin(session.index));
    return session;
  }

  Future<void> _load() async {
    final opened = <_PageSession>[];
    try {
      if (widget.pdfPath != null) {
        _pdf = await PdfDocument.openFile(widget.pdfPath!);
      }
      final count = _pdf != null
          ? _pdf!.pages.length
          : math.max(1, await _repository.pageCount(widget.notebookId));
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
        _fitted = false;
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

  // ---- Export ----

  /// Saves all pages, builds a PDF and opens the share sheet / save dialog.
  Future<void> exportPdf(String title) {
    return _runExclusive('Could not export the PDF.', () async {
      if (!await _flushAll()) {
        throw StateError('Unsaved changes could not be saved.');
      }
      final file = await ref
          .read(exportServiceProvider)
          .exportNotebookPdf(notebookId: widget.notebookId, title: title);
      await ref.read(shareServiceProvider).shareFile(file, title);
    });
  }

  // ---- Ruler and protractor ----

  double _scale() => _transform.value.storage[0];

  void _toggleMeasure(MeasureKind kind) {
    final m = _transform.value;
    final s = m.storage[0];
    _measure.toggle(
      kind,
      x: (_viewportW / 2 - m.storage[12]) / s,
      y: (_viewportH / 2 - m.storage[13]) / s,
    );
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

  Future<void> _insertImage() async {
    if (_busy) return;
    if (widget.pdfPath != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Images cannot be added to PDF notebooks'),
          ),
        );
      return;
    }
    final files = await FilePicker.pickFiles(type: FileType.image);
    final path = files.isEmpty ? null : files.first.path;
    if (path == null || !mounted) return;

    await _runExclusive('Could not insert the image.', () async {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'images'));
      await dir.create(recursive: true);
      final ext = p.extension(path).toLowerCase();
      final target = p.join(
        dir.path,
        '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}',
      );
      await File(path).copy(target);

      final index = _sessions.length;
      await _repository.insertPage(
        widget.notebookId,
        pageIndex: index,
        template: widget.template,
        imagePath: target,
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
        imagePath: source.imagePath,
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
    if (ref.read(appSettingsProvider).confirmDeletePage) {
      final confirmed = await ConfirmDeleteDialog.show(
        context,
        title: 'Delete page?',
        message:
            'Page ${index + 1} of ${_sessions.length} will be deleted. This cannot be undone.',
      );
      if (!confirmed || !mounted) return;
    }

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

  /// Top of the page cell (paper top is [kBleedY] lower).
  double _pageTop(int index) => _pad + index * _cellH;

  double get _contentHeight => _pad * 2 + _sessions.length * _cellH;

  double _clampTy(double ty, double scale) {
    final lowest = math.min(
      _margin,
      _viewportH - _contentHeight * scale - _margin,
    );
    return ty.clamp(lowest, _margin).toDouble();
  }

  void _setTransform(double scale, double tx, double ty) {
    _transform.value = Matrix4(
      scale,
      0,
      0,
      0, //
      0,
      scale,
      0,
      0, //
      0,
      0,
      1,
      0, //
      tx,
      ty,
      0,
      1,
    );
  }

  /// Keeps the pages centered. When the pages are larger than the viewport,
  /// panning is limited to their edges.
  void _keepCentered() {
    if (_sessions.isEmpty) return;
    final m = _transform.value;
    final scale = m.storage[0];
    final tx = m.storage[12];
    final ty = m.storage[13];
    final scaledW = _contentWidth * scale;
    final scaledH = _contentHeight * scale;

    final targetX = scaledW <= _viewportW
        ? (_viewportW - scaledW) / 2
        : tx.clamp(_viewportW - scaledW - _margin, _margin).toDouble();
    final targetY = scaledH + 2 * _margin <= _viewportH
        ? (_viewportH - scaledH) / 2
        : _clampTy(ty, scale);

    if ((targetX - tx).abs() < 0.5 && (targetY - ty).abs() < 0.5) return;
    _setTransform(scale, targetX, targetY);
  }

  /// First layout: fit narrow screens to the page width, never above the
  /// saved default zoom. Then restore the last position of this notebook.
  void _fitWidth() {
    final limit = ref.read(appSettingsProvider).defaultZoom;
    final scale = math
        .min(limit, _viewportW / _contentWidth)
        .clamp(0.25, 4.0)
        .toDouble();
    _fitted = true;
    _setTransform(scale, (_viewportW - _contentWidth * scale) / 2, 0);
    _restorePosition(scale);
  }

  void _restorePosition(double scale) {
    if (!_rememberPosition || _sessions.isEmpty) return;
    final saved = _settingsRepository.loadEditorPosition(widget.notebookId);
    if (saved == null) return;
    final index = saved.pageIndex.clamp(0, _sessions.length - 1);
    final offset = saved.offset.clamp(-_pad, kPageSize.height).toDouble();
    final ty = _clampTy(-(_pageTop(index) + offset) * scale, scale);
    _setTransform(scale, (_viewportW - _contentWidth * scale) / 2, ty);
    if (index != _activeIndex) setState(() => _activeIndex = index);
  }

  void _savePosition() {
    if (!_rememberPosition || !_fitted || _sessions.isEmpty) return;
    final m = _transform.value;
    final top = -m.storage[13] / m.storage[0];
    var index = 0;
    for (var i = 0; i < _sessions.length; i++) {
      if (_pageTop(i) <= top + 1) index = i;
    }
    unawaited(
      _settingsRepository.saveEditorPosition(
        widget.notebookId,
        EditorPosition(pageIndex: index, offset: top - _pageTop(index)),
      ),
    );
  }

  int get _visiblePage {
    final scale = _transform.value.storage[0];
    final ty = _transform.value.storage[13];
    final sceneY = (_viewportH / 2 - ty) / scale;
    final i = ((sceneY - _pad) / _cellH).floor();
    return i.clamp(0, _sessions.length - 1);
  }

  void _scrollToPage(int index) {
    if (index < 0 || index >= _sessions.length) return;
    final m = _transform.value;
    final scale = m.storage[0];
    final ty = _clampTy(-(_pageTop(index) + kBleedY) * scale + _pad, scale);
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
    final zoomWanted =
        HardwareKeyboard.instance.isControlPressed &&
        ref.read(appSettingsProvider).wheelZoom;
    if (zoomWanted) return; // InteractiveViewer zooms.
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
    _savePosition();
    for (final s in _sessions) {
      unawaited(s.autosave.flush());
    }
  }

  @override
  void dispose() {
    _savePosition();
    WidgetsBinding.instance.removeObserver(this);
    _transform.removeListener(_keepCentered);
    for (final s in _sessions) {
      s.close();
    }
    _pdf?.dispose();
    _settings.dispose();
    _measure.dispose();
    _transform.dispose();
    super.dispose();
  }

  // ---- PDF import ----

  Future<void> _importPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    final path = files.isEmpty ? null : files.first.path;
    if (path == null || !mounted) return;

    await _runExclusive('Could not import the PDF.', () async {
      if (!await _flushAll()) {
        throw StateError('Unsaved changes could not be saved.');
      }

      final notebook = await ref
          .read(importServiceProvider)
          .importPdf(path, folderId: widget.folderId);

      if (notebook == null) {
        throw StateError('PDF not found.');
      }

      if (mounted) {
        unawaited(context.push(AppRoutes.notebook(notebook.id)));
      }
    });
  }

  void _showPages() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => ListView.builder(
        itemCount: _sessions.length,
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text('Page ${i + 1}'),
          selected: i == _visiblePage,
          onTap: () {
            Navigator.of(sheet).pop();
            _scrollToPage(i);
          },
        ),
      ),
    );
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label is coming soon')));
  }

  Widget _paper(_PageSession session) {
    final image = session.imagePath;
    if (image != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SizedBox(
          width: kPageSize.width,
          height: kPageSize.height,
          child: Image.file(
            File(image),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      );
    }

    final pdf = _pdf;
    if (pdf == null || session.index >= pdf.pages.length) {
      return PaperView(template: session.template);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: kPageSize.width,
        height: kPageSize.height,
        child: PdfPageView(document: pdf, pageNumber: session.index + 1),
      ),
    );
  }

  // ---- UI ----

  /// One page cell: the paper plus a drawable margin around it. Pointer
  /// input and ink cover the whole cell, so you can draw on the gray area.
  Widget _buildPage(_PageSession session) {
    return SizedBox(
      width: kCellSize.width,
      height: kCellSize.height,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _setActive(session.index),
        child: DrawingSurface(
          controller: session.controller,
          allowTouch: _fingerDraws,
          origin: kPaperOrigin,
          bounds: Offset.zero & kPageSize,
          child: Stack(
            children: [
              Positioned(left: kBleedX, top: kBleedY, child: _paper(session)),
              Positioned.fill(
                child: ClipRect(
                  clipper: const _PaperClipper(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CommittedInkLayer(
                        controller: session.controller,
                        origin: kPaperOrigin,
                      ),
                      LiveInkLayer(
                        controller: session.controller,
                        origin: kPaperOrigin,
                      ),
                      SelectionLayer(
                        controller: session.controller,
                        origin: kPaperOrigin,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

    final pages = SizedBox(
      width: _contentWidth,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(_pad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final s in _sessions) _buildPage(s)],
            ),
          ),
          Positioned.fill(
            child: MeasureOverlay(controller: _measure, scale: _scale),
          ),
        ],
      ),
    );

    final anyDrawing = Listenable.merge([
      for (final s in _sessions) s.controller,
      _measure,
    ]);

    final editor = Column(
      children: [
        FloatingToolbar(
          controller: _active,
          fingerDraws: _fingerDraws,
          onFingerDrawsChanged: (v) => setState(() => _fingerDraws = v),
          busy: _busy,
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.library),
          onPages: _showPages,
          onExport: () => unawaited(exportPdf(widget.title)),
          onImportPdf: () => unawaited(_importPdf()),
          onInsertImage: () => unawaited(_insertImage()),
          onAddPage: () => unawaited(_addPage()),
          onToggleMeasure: _toggleMeasure,
          onSettings: () => context.push(AppRoutes.settings),
          onComingSoon: _comingSoon,
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
                          final busyInput =
                              _sessions.any((s) => s.controller.isDrawing) ||
                              _measure.interacting;
                          return InteractiveViewer(
                            transformationController: _transform,
                            constrained: false,
                            alignment: Alignment.topLeft,
                            minScale: 0.25,
                            maxScale: 4,
                            boundaryMargin: const EdgeInsets.all(
                              double.infinity,
                            ),
                            panEnabled: !busyInput,
                            scaleEnabled: true,
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
            onDelete: _sessions.length > 1
                ? () => unawaited(_deletePage())
                : null,
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
        ): () =>
            _active.redo(),
        const SingleActivator(LogicalKeyboardKey.delete): () =>
            _active.deleteSelection(),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _active.clearSelection(),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            _scrollToPage(_visiblePage - 1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            _scrollToPage(_visiblePage + 1),
        const SingleActivator(LogicalKeyboardKey.keyR): () =>
            _toggleMeasure(MeasureKind.ruler),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
            unawaited(exportPdf(widget.title)),
      },
      child: Focus(autofocus: true, child: editor),
    );
  }
}

class _PaperClipper extends CustomClipper<Rect> {
  const _PaperClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(kBleedX, kBleedY, kPageSize.width, kPageSize.height);

  @override
  bool shouldReclip(_PaperClipper oldClipper) => false;
}
