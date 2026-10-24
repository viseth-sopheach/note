import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';

import '../../../app/glass/glass_dialog.dart';
import '../../../app/glass/glass_list_tile.dart';
import '../../../app/glass/glass_scroll_thumb.dart';
import '../../../app/glass/glass_theme.dart';
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
import '../application/page_images_controller.dart';
import '../application/tool_settings.dart';
import '../domain/page_repository.dart';
import '../domain/stroke_tool.dart';
import 'dialogs/paper_template_dialog.dart';
import 'drawing/drawing_surface.dart';
import 'drawing/image_layer.dart';
import 'drawing/ink_layers.dart';
import 'drawing/selection_layer.dart';
import 'editor_stack.dart';
import 'measure/measure_overlay.dart';
import 'paper/page_metrics.dart';
import 'paper/paper_painter.dart';
import 'paper/paper_view.dart';
import 'toolbar/floating_toolbar.dart';

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
    required this.images,
    required this.autosave,
  });

  /// Changes when pages before this one are added or deleted.
  int index;
  final DrawingController controller;
  final PaperTemplate template;
  final String? imagePath;
  final PageImagesController images;
  AutosaveController autosave;

  void close() {
    unawaited(autosave.dispose());
    unawaited(images.close());
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
  static const double _margin = 88;

  /// Width of the scrollable content: page cell (paper + drawable margin)
  /// plus padding.
  static double get _contentWidth => kCellSize.width + _pad * 2;

  static double get _cellH => kCellSize.height;

  late final ToolSettings _settings;
  late final SettingsRepository _settingsRepository;
  late final bool _rememberPosition;
  final MeasureController _measure = MeasureController();
  final TransformationController _transform = TransformationController();
  final ValueNotifier<bool> _scrolling = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _atBottom = ValueNotifier<bool>(false);
  Timer? _idleTimer;
  double _lastTy = 0;
  double _lastScale = 1;
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
    _transform.addListener(_onTransform);
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

  void _onTransform() {
    if (!_fitted || _sessions.isEmpty) return;
    final m = _transform.value;
    final scale = m.storage[0];
    final ty = m.storage[13];
    final scaleChanged = (scale - _lastScale).abs() > 0.001;
    final moved = (ty - _lastTy).abs() > 0.5 || scaleChanged;
    _lastTy = ty;
    _lastScale = scale;
    if (scaleChanged && _active.hasSelection) _active.refreshView();
    final scaledH = _contentHeight * scale;
    final fits = scaledH + 2 * _margin <= _viewportH;
    final lowest = math.min(_margin, _viewportH - scaledH - _margin);
    _atBottom.value = fits || ty <= lowest + 8;
    if (!moved) return;
    _scrolling.value = true;
    _idleTimer?.cancel();
    _idleTimer = Timer(
      const Duration(milliseconds: 1400),
      () => _scrolling.value = false,
    );
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
    final pageImages = await _repository.loadImages(
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
      images: PageImagesController(
        repository: _repository,
        notebookId: widget.notebookId,
        pageIndex: index,
        pageSize: kPageSize,
        initial: pageImages,
      ),
      autosave: _newAutosave(controller, index),
    );
    controller.snapSegments = () =>
        _measure.edgesRelativeTo(_paperOrigin(session.index));
    controller.viewScale = _scale;
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
    await Future.wait([
      for (final s in _sessions) ...[s.autosave.flush(), s.images.flush()],
    ]);
    return _sessions.every(
      (s) => !s.autosave.hasUnsavedChanges && !s.images.hasUnsavedChanges,
    );
  }

  /// Points the page at a new index and restarts its autosave there.
  Future<void> _rebind(_PageSession session, int index) async {
    if (session.index == index) return;
    await session.autosave.dispose();
    await session.images.rebind(index);
    session.index = index;
    session.autosave = _newAutosave(session.controller, index);
  }

  void _scheduleScroll(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToPage(index);
    });
  }

  /// Asks for a paper template, then adds the page.
  Future<void> _addPage() async {
    if (_busy || _sessions.isEmpty) return;
    final template = await PaperTemplateDialog.show(
      context,
      title: 'Add page',
      confirmLabel: 'Add',
      initial: _sessions[_visiblePage].template,
    );
    if (template == null || !mounted) return;
    await _appendPage(template);
  }

  /// Adds a page that follows the template of the page in view.
  Future<void> _addPageSameTemplate() async {
    if (_busy || _sessions.isEmpty) return;
    await _appendPage(_sessions[_visiblePage].template);
  }

  Future<void> _appendPage(PaperTemplate template) {
    return _runExclusive('Could not add a page.', () async {
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

  /// Returns the chosen image path, or null when cancelled or unavailable.
  /// Phones can pick from files or take a photo; desktop uses the file picker.
  Future<String?> _pickImagePath() async {
    try {
      final mobile =
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      var camera = false;

      if (mobile) {
        final choice = await showGlassSheet<String>(
          context: context,
          builder: (sheet) => Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassListTile(
                    leading: Icons.photo_library_outlined,
                    title: 'Photo library / Files',
                    onTap: () => Navigator.of(sheet).pop('files'),
                  ),
                  GlassListTile(
                    leading: Icons.photo_camera_outlined,
                    title: 'Take photo',
                    onTap: () => Navigator.of(sheet).pop('camera'),
                  ),
                ],
              ),
            ),
          ),
        );
        if (choice == null || !mounted) return null;
        camera = choice == 'camera';
      }

      if (camera) {
        final shot = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 2480,
          imageQuality: 90,
        );
        return shot?.path;
      }

      final files = await FilePicker.pickFiles(type: FileType.image);
      return files.isEmpty ? null : files.first.path;
    } catch (error, stack) {
      developer.log(
        'Image picker failed',
        name: 'editor',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not open the image picker.')),
          );
      }
      return null;
    }
  }

  /// Places a picked image on the page in view. The image can then be moved
  /// and resized with its handles.
  Future<void> _insertImage() async {
    if (_busy || _sessions.isEmpty) return;

    final path = await _pickImagePath();
    if (path == null || !mounted) return;

    await _runExclusive('Could not insert the image.', () async {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'images'));
      await dir.create(recursive: true);
      final ext = p.extension(path).toLowerCase();
      final target = File(
        p.join(dir.path, '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}'),
      );
      await File(path).copy(target.path);

      try {
        final natural = await _imageSize(target);
        final index = _visiblePage;
        final m = _transform.value;
        final sceneY = (_viewportH / 2 - m.storage[13]) / m.storage[0];
        final center = Offset(
          kPageSize.width / 2,
          (sceneY - _paperOrigin(index).dy)
              .clamp(0.0, kPageSize.height)
              .toDouble(),
        );

        _sessions[index].images.add(
          path: target.path,
          natural: natural,
          center: center,
        );
        _setActive(index);
      } catch (_) {
        if (await target.exists()) await target.delete();
        rethrow;
      }
    });
  }

  /// Reads the pixel size without decoding the whole image.
  Future<Size> _imageSize(File file) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
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
        images: source.images.images,
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

    // Center on the paper, not on the cell: the drawable bleed is symmetric,
    // so the content center is the paper center. Pan freely only once the
    // paper itself is wider than the viewport.
    final paperFits = kPageSize.width * scale <= _viewportW;
    final targetX = paperFits
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
    _setTransform(scale, (_viewportW - _contentWidth * scale) / 2, _margin);
    _restorePosition(scale);
    _idleTimer?.cancel();
    _scrolling.value = false;
    _lastTy = _transform.value.storage[13];
    _lastScale = _transform.value.storage[0];
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
    final ty = _clampTy(-(_pageTop(index) + kBleedY) * scale + _margin, scale);
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
      unawaited(s.images.flush());
    }
  }

  @override
  void dispose() {
    _savePosition();
    WidgetsBinding.instance.removeObserver(this);
    _transform.removeListener(_keepCentered);
    _transform.removeListener(_onTransform);
    _idleTimer?.cancel();
    _scrolling.dispose();
    _atBottom.dispose();
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
    showGlassSheet<void>(
      context: context,
      builder: (sheet) => Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
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
        ),
      ),
    );
  }

  Future<void> _showMoreSheet() async {
    final items = <({String value, IconData icon, String label})>[
      (value: 'ruler', icon: Icons.straighten, label: 'Ruler'),
      (value: 'protractor', icon: Icons.architecture, label: 'Protractor'),
      if (!_busy)
        (
          value: 'duplicate',
          icon: Icons.file_copy_outlined,
          label: 'Duplicate page',
        ),
      if (!_busy && _sessions.length > 1)
        (value: 'delete', icon: Icons.delete_outline, label: 'Delete page'),
      if (!_busy)
        (
          value: 'export',
          icon: Icons.picture_as_pdf_outlined,
          label: 'Export PDF',
        ),
      (value: 'settings', icon: Icons.settings_outlined, label: 'Settings'),
    ];

    final action = await showGlassSheet<String>(
      context: context,
      builder: (sheet) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                GlassListTile(
                  leading: item.icon,
                  title: item.label,
                  onTap: () => Navigator.of(sheet).pop(item.value),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'ruler':
        _toggleMeasure(MeasureKind.ruler);
      case 'protractor':
        _toggleMeasure(MeasureKind.protractor);
      case 'duplicate':
        unawaited(_duplicatePage());
      case 'delete':
        unawaited(_deletePage());
      case 'export':
        unawaited(exportPdf(widget.title));
      case 'settings':
        unawaited(context.push(AppRoutes.settings));
    }
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label is coming soon')));
  }

  /// Dark paper only for template pages. PDF and image pages stay light.
  bool _darkPaper(_PageSession session) =>
      Theme.of(context).brightness == Brightness.dark &&
      session.imagePath == null &&
      _pdf == null;

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
      return PaperView(template: session.template, dark: _darkPaper(session));
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
    final dark = _darkPaper(session);

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
          isClaimed: (point) {
            final claimed = session.images.claims(
              point,
              selectToolActive: session.controller.tool == StrokeTool.select,
            );
            if (!claimed) session.images.select(null);
            return claimed;
          },
          child: Stack(
            children: [
              Positioned(left: kBleedX, top: kBleedY, child: _paper(session)),
              Positioned.fill(
                child: ImageLayer(
                  controller: session.images,
                  drawing: session.controller,
                  scale: _scale,
                  origin: kPaperOrigin,
                ),
              ),
              Positioned.fill(
                child: ClipRect(
                  clipper: const _PaperClipper(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CommittedInkLayer(
                        controller: session.controller,
                        origin: kPaperOrigin,
                        darkPaper: dark,
                      ),
                      LiveInkLayer(
                        controller: session.controller,
                        origin: kPaperOrigin,
                        darkPaper: dark,
                      ),
                      SelectionLayer(
                        controller: session.controller,
                        origin: kPaperOrigin,
                        darkPaper: dark,
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
      for (final s in _sessions) s.images,
      _measure,
    ]);

    final canvas = Stack(
      children: [
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: _busy,
            child: ColoredBox(
              color: context.glass.canvas,
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
                              _sessions.any(
                                (s) =>
                                    s.controller.isDrawing ||
                                    s.images.interacting,
                              ) ||
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
        Positioned.fill(
          child: ListenableBuilder(
            listenable: Listenable.merge([_transform, _scrolling]),
            builder: (context, _) {
              final m = _transform.value;
              final scale = m.storage[0];
              final ty = m.storage[13];
              final total = _contentHeight * scale + 2 * _margin;
              final range = total - _viewportH;
              final fraction = range <= 0
                  ? 1.0
                  : (_viewportH / total).clamp(0.0, 1.0).toDouble();
              final position = range <= 0
                  ? 0.0
                  : ((_margin - ty) / range).clamp(0.0, 1.0).toDouble();
              return GlassScrollThumb(
                visible: _scrolling.value && range > 0,
                fraction: fraction,
                position: position,
              );
            },
          ),
        ),
      ],
    );

    final toolbar = Column(
      mainAxisSize: MainAxisSize.min,
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
          onAddPage: () => unawaited(_addPageSameTemplate()),
          onAddTemplate: () => unawaited(_addPage()),
          onToggleMeasure: _toggleMeasure,
          onSettings: () => context.push(AppRoutes.settings),
          onComingSoon: _comingSoon,
          onDuplicatePage: () => unawaited(_duplicatePage()),
          onDeletePage: _sessions.length > 1
              ? () => unawaited(_deletePage())
              : null,
        ),
        SizedBox(
          height: 2,
          child: _busy ? const LinearProgressIndicator() : null,
        ),
      ],
    );

    return EditorStack(
      canvas: canvas,
      toolbar: toolbar,
      transform: _transform,
      scrolling: _scrolling,
      atBottom: _atBottom,
      pageIndex: () => _visiblePage,
      pageCount: _sessions.length,
      busy: _busy,
      onPrevious: () => _scrollToPage(_visiblePage - 1),
      onNext: () => _scrollToPage(_visiblePage + 1),
      onAdd: () => unawaited(_addPageSameTemplate()),
      onAddTemplate: () => unawaited(_addPage()),
      onAddImage: () => unawaited(_insertImage()),
      onImport: () => unawaited(_importPdf()),
      onMore: () => unawaited(_showMoreSheet()),
    );
  }
}

class _PaperClipper extends CustomClipper<Rect> {
  const _PaperClipper();

  @override
  Rect getClip(Size size) => Offset.zero & size;

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
