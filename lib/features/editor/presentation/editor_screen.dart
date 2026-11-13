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

import '../../../app/glass/glass_button.dart';
import '../../../app/glass/glass_dialog.dart';
import '../../../app/glass/glass_list_tile.dart';
import '../../../app/glass/glass_menu.dart';
import '../../../app/glass/glass_theme.dart';
import '../../../app/routes.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/paper_template.dart';
import '../../library/presentation/dialogs/confirm_delete_dialog.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/domain/editor_position.dart';
import '../../settings/domain/settings_repository.dart';
import '../../sharing/application/sharing_providers.dart';
import '../../sharing/presentation/export_options_dialog.dart';
import '../application/autosave_controller.dart';
import '../application/canvas_motion.dart';
import '../application/drawing_controller.dart';
import '../application/editor_providers.dart';
import '../application/measure_controller.dart';
import '../application/page_images_controller.dart';
import '../application/page_texts_controller.dart';
import '../application/tool_settings.dart';
import '../domain/page_image.dart';
import '../domain/page_repository.dart';
import '../domain/page_text.dart';
import '../domain/shape_choice.dart';
import '../domain/stroke.dart';
import '../domain/stroke_tool.dart';
import 'dialogs/paper_template_dialog.dart';
import 'drawing/drawing_surface.dart';
import 'drawing/image_layer.dart';
import 'drawing/ink_layers.dart';
import 'drawing/selection_layer.dart';
import 'drawing/text_layer.dart';
import 'editor_stack.dart';
import 'gestures/one_finger_double_tap.dart';
import 'gestures/stylus_gate.dart';
import 'gestures/two_finger_double_tap.dart';
import 'gestures/two_finger_scroll_guard.dart';
import 'measure/measure_overlay.dart';
import 'paper/page_metrics.dart';
import 'paper/paper_colors.dart';
import 'paper/paper_painter.dart';
import 'paper/paper_view.dart';
import 'paper/pdf_page_layer.dart';
import 'toolbar/floating_toolbar.dart';
import 'toolbar/ink_palette.dart';
import 'toolbar/selection_action_bar.dart';
import 'toolbar/tool_icons.dart';
import 'widgets/web_scrollbar.dart';

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

class _PageClip {
  const _PageClip({
    required this.template,
    required this.imagePath,
    required this.strokes,
    required this.images,
    required this.texts,
  });

  final PaperTemplate template;
  final String? imagePath;
  final List<Stroke> strokes;
  final List<PageImage> images;
  final List<PageText> texts;
}

class _PageSession {
  _PageSession({
    required this.index,
    required this.controller,
    required this.template,
    required this.imagePath,
    required this.images,
    required this.texts,
    required this.autosave,
  });

  int index;

  final DrawingController controller;
  final PaperTemplate template;
  final String? imagePath;
  final PageImagesController images;
  final PageTextsController texts;

  AutosaveController autosave;

  void close() {
    unawaited(autosave.dispose());
    unawaited(images.close());
    unawaited(texts.close());
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const double _pad = 24;
  static const double _margin = 88;

  /// Paper width never drops below this fraction of the viewport width.
  static const double _minPaperWidthFraction = 0.15;

  /// Maximum zoom, relative to fit-to-width (100%): 500%.
  static const double _maxZoomMultiplier = 5.0;

  static const double _doubleTapZoomFraction = 0.98;

  static _PageClip? _pageClip;

  /// Space kept below the last page so the New Page card never covers it.
  static double get _bottomInset => NewPageCard.height + 32;

  static double get _contentWidth => kCellSize.width + _pad * 2;

  static double get _cellH => kCellSize.height;

  static const String _highlightAction = 'highlight';
  static const String _colorAction = 'color';
  static const int _removeFill = 0;

  late final ToolSettings _settings;
  late final SettingsRepository _settingsRepository;
  late final bool _rememberPosition;

  late final CanvasMotion _view;

  final MeasureController _measure = MeasureController();

  final TransformationController _transform = TransformationController();

  final ValueNotifier<bool> _scrolling = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _atBottom = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _zoomAllowed = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _twoFingerScroll = ValueNotifier<bool>(false);

  Timer? _idleTimer;
  Timer? _snapTimer;

  double _lastTy = 0;
  double _lastScale = 1;

  final List<_PageSession> _sessions = [];

  late final PageRepository _repository;

  PdfDocument? _pdf;

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  bool _fitted = false;
  bool _textMode = false;

  int _activeIndex = 0;
  int _firstVisible = 0;
  int _lastVisible = 0;

  double _viewportW = 600;
  double _viewportH = 600;

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

    _view = CanvasMotion(
      vsync: this,
      transform: _transform,
      clamp: _clampTranslation,
      reduceMotion: () => MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );

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

  // ------------------------------------------------------------
  // Canvas transformation
  // ------------------------------------------------------------

  void _updateVisibleRange() {
    if (!mounted || _sessions.isEmpty) return;
    final m = _transform.value;
    final scale = m.storage[0];
    final top = -m.storage[13] / scale;
    final bottom = (_viewportH - m.storage[13]) / scale;
    final lo = (((top - _pad) / _cellH).floor() - 1).clamp(
      0,
      _sessions.length - 1,
    );
    final hi = (((bottom - _pad) / _cellH).floor() + 1).clamp(
      0,
      _sessions.length - 1,
    );
    if (lo == _firstVisible && hi == _lastVisible) return;
    setState(() {
      _firstVisible = lo;
      _lastVisible = hi;
    });
  }

  void _onTransform() {
    if (!_fitted || _sessions.isEmpty) return;

    _updateVisibleRange();

    final m = _transform.value;

    final scale = m.storage[0];
    final ty = m.storage[13];

    final scaleChanged = (scale - _lastScale).abs() > 0.001;

    final moved = (ty - _lastTy).abs() > 0.5 || scaleChanged;

    _lastTy = ty;
    _lastScale = scale;

    if (scaleChanged && _active.hasSelection) {
      _active.refreshView();
    }

    final scaledH = _contentHeight * scale;

    final fits = scaledH + 2 * _margin <= _viewportH;

    final lowest = math.min(
      _margin,
      _viewportH - scaledH - _margin - _bottomInset,
    );

    _atBottom.value = fits || ty <= lowest + 8;

    if (!moved) return;

    _snapTimer?.cancel();
    _snapTimer = Timer(const Duration(milliseconds: 180), _snapToBottom);

    _scrolling.value = true;

    _idleTimer?.cancel();

    _idleTimer = Timer(
      const Duration(milliseconds: 1400),
      () => _scrolling.value = false,
    );
  }

  Offset _clampTranslation(Offset t, double scale) {
    final scaledW = _contentWidth * scale;
    final scaledH = _contentHeight * scale;

    final double x;
    if (scale <= _baseScale * 1.0001) {
      x = (_viewportW - scaledW) / 2;
    } else {
      final left = (_pad + kBleedX) * scale;
      final right = (_pad + kBleedX + kPageSize.width) * scale;
      x = t.dx.clamp(_viewportW - right, -left).toDouble();
    }

    final y = scaledH + 2 * _margin <= _viewportH
        ? (_viewportH - scaledH) / 2
        : _clampTy(t.dy, scale);

    return Offset(x, y);
  }

  void _keepCentered() {
    if (_sessions.isEmpty) return;

    final m = _transform.value;
    final raw = m.storage[0];
    final scale = raw.clamp(_minScale, _maxScale).toDouble();

    final target = _clampTranslation(
      Offset(m.storage[12], m.storage[13]),
      scale,
    );

    if ((scale - raw).abs() < 1e-6 &&
        (target.dx - m.storage[12]).abs() < 0.5 &&
        (target.dy - m.storage[13]).abs() < 0.5) {
      return;
    }

    _setTransform(scale, target.dx, target.dy);
  }

  double _scale() => _transform.value.storage[0];

  // ------------------------------------------------------------
  // Canvas motion and scrolling
  // ------------------------------------------------------------

  double get _baseScale => _viewportW / kPageSize.width; // 100% = fit width
  double get _minScale => _viewportW * _minPaperWidthFraction / kPageSize.width;
  double get _maxScale => _baseScale * _maxZoomMultiplier;
  double get _fitScale => _baseScale;
  double get _paperFitScale => _baseScale * _doubleTapZoomFraction;

  void _fitToWidth() {
    if (!_fitted || _sessions.isEmpty) return;

    final m = _transform.value;

    final target = _paperFitScale;

    final sceneY = (_viewportH / 2 - m.storage[13]) / m.storage[0];

    final translation = _clampTranslation(
      Offset(
        (_viewportW - _contentWidth * target) / 2,
        _viewportH / 2 - sceneY * target,
      ),
      target,
    );

    _view.animateTo(scale: target, translation: translation);

    unawaited(HapticFeedback.selectionClick());
  }

  /// When scrolling stops past the end of the last page, glide to the spot
  /// where the New Page card and bottom actions are fully visible.
  void _snapToBottom() {
    if (!mounted || !_fitted || _sessions.isEmpty || _busy) return;
    final m = _transform.value;
    final scale = m.storage[0];
    final ty = m.storage[13];
    if (_contentHeight * scale + 2 * _margin <= _viewportH) return;

    final pageEnd = _viewportH - _contentHeight * scale - _margin;
    final target = pageEnd - _bottomInset;
    if (ty >= pageEnd - 4 || ty <= target + 8) return;

    _view.animateTo(scale: scale, translation: Offset(m.storage[12], target));
  }

  void _scrollByFingers(Offset delta) {
    _view.stop();
    final m = _transform.value;
    final s = m.storage[0];
    final t = _clampTranslation(
      Offset(m.storage[12] + delta.dx, m.storage[13] + delta.dy),
      s,
    );
    _setTransform(s, t.dx, t.dy);
  }

  void _flingByFingers(Offset velocity) {
    if (velocity.distance < 200) return;
    _view.scrollBy(velocity * 0.25);
  }

  void _scrollTo({double? x, double? y}) {
    final m = _transform.value;

    _setTransform(
      m.storage[0],
      x == null ? m.storage[12] : _margin - x,
      y == null ? m.storage[13] : _margin - y,
    );
  }

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Widget _wheel(Widget child) {
    return Listener(onPointerSignal: _onSignal, child: child);
  }

  Widget _scrollbars() {
    final m = _transform.value;

    final scale = m.storage[0];

    final showH = false;

    const bar = 16.0;

    return Stack(
      children: [
        Positioned(
          top: 64,
          right: 0,
          bottom: showH ? bar : 0,
          width: bar,
          child: _wheel(
            WebScrollbar(
              axis: Axis.vertical,
              viewport: _viewportH,
              content: _contentHeight * scale + 2 * _margin + _bottomInset,
              position: _margin - m.storage[13],
              alwaysVisible: _isDesktop,
              revealed: _scrolling.value,
              onDragStart: _view.stop,
              onScrollTo: (p) => _scrollTo(y: p),
              onPage: (d) => _view.scrollBy(Offset(0, -d * _viewportH * 0.9)),
            ),
          ),
        ),
        if (showH)
          Positioned(
            left: 0,
            right: bar,
            bottom: 0,
            height: bar,
            child: _wheel(
              WebScrollbar(
                axis: Axis.horizontal,
                viewport: _viewportW,
                content: _contentWidth * scale + 2 * _margin,
                position: _margin - m.storage[12],
                alwaysVisible: _isDesktop,
                revealed: _scrolling.value,
                onDragStart: _view.stop,
                onScrollTo: (p) => _scrollTo(x: p),
                onPage: (d) => _view.scrollBy(Offset(-d * _viewportW * 0.9, 0)),
              ),
            ),
          ),
      ],
    );
  }

  void _zoomAt(Offset focal, double factor) {
    final m = _transform.value;
    final s = m.storage[0];
    final target = (s * factor).clamp(_minScale, _maxScale).toDouble();
    if (target == s) return;
    final sceneX = (focal.dx - m.storage[12]) / s;
    final sceneY = (focal.dy - m.storage[13]) / s;
    final t = _clampTranslation(
      Offset(focal.dx - sceneX * target, focal.dy - sceneY * target),
      target,
    );
    _view.stop();
    _setTransform(target, t.dx, t.dy);
  }

  /// Mouse wheel scrolls the canvas. Ctrl + wheel zooms.
  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final scroll = e as PointerScrollEvent;
      if (HardwareKeyboard.instance.isControlPressed &&
          ref.read(appSettingsProvider).wheelZoom) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          _zoomAt(
            box.globalToLocal(scroll.position),
            math.exp(-scroll.scrollDelta.dy / 400),
          );
        }
        return;
      }
      _view.scrollBy(Offset(0, -scroll.scrollDelta.dy));
    });
  }

  // ------------------------------------------------------------
  // Page sessions
  // ------------------------------------------------------------

  AutosaveController _newAutosave(DrawingController controller, int index) {
    return AutosaveController(
      controller: controller,
      repository: _repository,
      notebookId: widget.notebookId,
      pageIndex: index,
    );
  }

  Offset _paperOrigin(int index) {
    return Offset(_pad + kBleedX, _pad + index * _cellH + kBleedY);
  }

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

    final pageTexts = await _repository.loadTexts(
      widget.notebookId,
      pageIndex: index,
    );

    final controller = DrawingController(
      settings: _settings,
      undoLimit: ref.read(appSettingsProvider).undoLimit,
    );

    controller.replaceStrokes(strokes);

    controller.onShapeRecognized = () {
      unawaited(HapticFeedback.selectionClick());
    };

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
      texts: PageTextsController(
        repository: _repository,
        notebookId: widget.notebookId,
        pageIndex: index,
        pageSize: kPageSize,
        initial: pageTexts,
      ),
      autosave: _newAutosave(controller, index),
    );

    controller.snapSegments = () {
      return _measure.edgesRelativeTo(_paperOrigin(session.index));
    };

    controller.viewScale = _scale;

    return session;
  }

  Future<void> _load() async {
    final opened = <_PageSession>[];

    try {
      if (widget.pdfPath != null) {
        _pdf = await PdfDocument.openFile(widget.pdfPath!);
      }

      final saved = await _repository.pageCount(widget.notebookId);
      final count = _pdf != null
          ? math.max(_pdf!.pages.length, saved)
          : math.max(1, saved);

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
        _firstVisible = 0;
        _lastVisible = math.min(opened.length - 1, 2);
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

  // ------------------------------------------------------------
  // Export
  // ------------------------------------------------------------

  Future<void> exportPdf(String title) async {
    final options = await ExportOptionsDialog.show(context);
    if (options == null || !mounted) return;

    return _runExclusive('Could not export the PDF.', () async {
      if (!await _flushAll()) {
        throw StateError('Unsaved changes could not be saved.');
      }
      final file = await ref
          .read(exportServiceProvider)
          .exportNotebookPdf(
            notebookId: widget.notebookId,
            title: title,
            template: widget.template,
            pdfPath: widget.pdfPath,
            options: options,
          );
      await ref.read(shareServiceProvider).shareFile(file, title);
    });
  }

  // ------------------------------------------------------------
  // Ruler and protractor
  // ------------------------------------------------------------

  void _toggleMeasure(MeasureKind kind) {
    final m = _transform.value;

    final s = m.storage[0];

    _measure.toggle(
      kind,
      x: (_viewportW / 2 - m.storage[12]) / s,
      y: (_viewportH / 2 - m.storage[13]) / s,
    );
  }

  // ------------------------------------------------------------
  // Text tool
  // ------------------------------------------------------------

  void _setTextMode(bool on) {
    if (_textMode == on) return;

    if (on) {
      _active.clearSelection();
    } else {
      for (final s in _sessions) {
        s.texts.select(null);
      }
    }

    setState(() => _textMode = on);
  }

  void _toggleTextTool() {
    _setTextMode(!_textMode);
  }

  void _createText(_PageSession session, Offset paperPoint) {
    if (_busy || !(Offset.zero & kPageSize).contains(paperPoint)) {
      return;
    }

    final saved = ref.read(appSettingsProvider);

    final color = _settings.tool == StrokeTool.pen
        ? _settings.colorValue
        : saved.penColorValue;

    _setActive(session.index);

    session.texts.add(at: paperPoint, colorValue: color);
  }

  // ------------------------------------------------------------
  // Exclusive operations and saving
  // ------------------------------------------------------------

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
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _flushAll() async {
    await Future.wait([
      for (final s in _sessions) ...[
        s.autosave.flush(),
        s.images.flush(),
        s.texts.flush(),
      ],
    ]);

    return _sessions.every(
      (s) =>
          !s.autosave.hasUnsavedChanges &&
          !s.images.hasUnsavedChanges &&
          !s.texts.hasUnsavedChanges,
    );
  }

  Future<void> _rebind(_PageSession session, int index) async {
    if (session.index == index) return;

    await session.autosave.dispose();

    await session.images.rebind(index);

    await session.texts.rebind(index);

    session.index = index;

    session.autosave = _newAutosave(session.controller, index);
  }

  // ------------------------------------------------------------
  // Page actions
  // ------------------------------------------------------------

  void _scheduleScroll(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToPage(index);
        _updateVisibleRange();
      }
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

    await _appendPage(template);
  }

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
                    onTap: () {
                      Navigator.of(sheet).pop('files');
                    },
                  ),
                  GlassListTile(
                    leading: Icons.photo_camera_outlined,
                    title: 'Take photo',
                    onTap: () {
                      Navigator.of(sheet).pop('camera');
                    },
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
        final shot = await ImagePicker().pickImage(source: ImageSource.camera);

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
        if (await target.exists()) {
          await target.delete();
        }

        rethrow;
      }
    });
  }

  Future<void> _addImagePages() async {
    if (_busy || _sessions.isEmpty) return;

    final files = await ImagePicker().pickMultiImage();
    final paths = [for (final f in files) f.path];
    if (paths.isEmpty || !mounted) return;

    await _runExclusive('Could not add the images.', () async {
      final service = ref.read(importServiceProvider);
      for (final path in paths) {
        final stored = await service.storeImage(path);
        if (stored == null) continue;

        final index = _sessions.length;
        await _repository.insertPage(
          widget.notebookId,
          pageIndex: index,
          template: _sessions.last.template,
          imagePath: stored,
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
      }
      _scheduleScroll(_sessions.length - 1);
    });
  }

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
        texts: source.texts.texts,
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

  void _copyPage() {
    if (_busy || _sessions.isEmpty) return;
    final index = _visiblePage;
    final s = _sessions[index];
    setState(() {
      _pageClip = _PageClip(
        template: s.template,
        imagePath: s.imagePath,
        strokes: List<Stroke>.of(s.controller.strokes),
        images: List<PageImage>.of(s.images.images),
        texts: List<PageText>.of(s.texts.texts),
      );
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Page ${index + 1} copied')));
  }

  Future<void> _pastePage() async {
    final clip = _pageClip;
    if (clip == null || _busy || _sessions.isEmpty) return;
    final current = _visiblePage;
    final count = _sessions.length;

    final target = await showGlassDialog<int>(
      context: context,
      builder: (_) => _PasteDestinationDialog(count: count, current: current),
    );
    if (target == null || !mounted) return;

    await _runExclusive('Could not paste the page.', () async {
      if (!await _flushAll()) {
        throw StateError('Unsaved changes could not be saved.');
      }

      await _repository.insertPage(
        widget.notebookId,
        pageIndex: target,
        template: clip.template,
        strokes: clip.strokes,
        imagePath: clip.imagePath,
        images: clip.images,
        texts: clip.texts,
      );

      final pasted = await _openPage(target);
      final updated = [..._sessions]..insert(target, pasted);
      for (var i = target + 1; i < updated.length; i++) {
        await _rebind(updated[i], i);
      }

      if (!mounted) {
        pasted.close();
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        removed.close();
      });

      _scheduleScroll(next);
    });
  }

  // ------------------------------------------------------------
  // Scrolling and zooming
  // ------------------------------------------------------------

  double _pageTop(int index) {
    return _pad + index * _cellH;
  }

  double get _contentHeight {
    return _pad * 2 + _sessions.length * _cellH;
  }

  double _clampTy(double ty, double scale) {
    final lowest = math.min(
      _margin,
      _viewportH - _contentHeight * scale - _margin - _bottomInset,
    );

    return ty.clamp(lowest, _margin).toDouble();
  }

  void _setTransform(double scale, double tx, double ty) {
    _transform.value = Matrix4(
      scale,
      0,
      0,
      0,
      0,
      scale,
      0,
      0,
      0,
      0,
      1,
      0,
      tx,
      ty,
      0,
      1,
    );
  }

  void _fitWidth() {
    final limit = ref.read(appSettingsProvider).defaultZoom;

    final scale = _baseScale;

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

    if (index != _activeIndex) {
      setState(() => _activeIndex = index);
    }
  }

  void _savePosition() {
    if (!_rememberPosition || !_fitted || _sessions.isEmpty) {
      return;
    }

    final m = _transform.value;

    final top = -m.storage[13] / m.storage[0];

    var index = 0;

    for (var i = 0; i < _sessions.length; i++) {
      if (_pageTop(i) <= top + 1) {
        index = i;
      }
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

    _sessions[_activeIndex].texts.select(null);

    setState(() => _activeIndex = index);
  }

  // ------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;

    _savePosition();

    for (final s in _sessions) {
      unawaited(s.autosave.flush());
      unawaited(s.images.flush());
      unawaited(s.texts.flush());
    }
  }

  @override
  void dispose() {
    _savePosition();

    WidgetsBinding.instance.removeObserver(this);

    _transform.removeListener(_keepCentered);
    _transform.removeListener(_onTransform);

    _idleTimer?.cancel();
    _snapTimer?.cancel();

    _scrolling.dispose();
    _atBottom.dispose();
    _zoomAllowed.dispose();
    _twoFingerScroll.dispose();

    for (final s in _sessions) {
      s.close();
    }

    final pdf = _pdf;
    if (pdf != null) unawaited(pdf.dispose());

    _settings.dispose();

    _measure.dispose();

    _view.dispose();

    _transform.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // PDF import
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // Page list
  // ------------------------------------------------------------

  void _showPages() {
    final current = _visiblePage;
    showGlassSheet<void>(
      context: context,
      builder: (sheet) {
        final colors = Theme.of(sheet).colorScheme;
        return Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _sessions.length,
              itemBuilder: (_, i) {
                final selected = i == current;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: 'Page ${i + 1}',
                  child: InkWell(
                    onTap: () {
                      Navigator.of(sheet).pop();
                      _scrollToPage(i);
                    },
                    child: Container(
                      color: selected
                          ? colors.primary.withValues(alpha: 0.14)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: selected
                                    ? colors.primary
                                    : colors.outlineVariant,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: _pageThumb(_sessions[i], 60),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Page ${i + 1}',
                              style: Theme.of(sheet).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selected ? colors.primary : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Read-only miniature of a page: paper, images, text and ink.
  Widget _pageThumb(_PageSession s, double width) {
    final dark = _darkPaper(s);
    final height = width * kPageSize.height / kPageSize.width;

    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: kPageSize.width,
          height: kPageSize.height,
          child: IgnorePointer(
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(child: _paper(s)),
                  for (final img in s.images.images)
                    Positioned(
                      left: img.x,
                      top: img.y,
                      width: img.width,
                      height: img.height,
                      child: Image.file(
                        File(img.path),
                        fit: BoxFit.fill,
                        cacheWidth: 256,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  for (final t in s.texts.texts)
                    Positioned(
                      left: t.x + PageTextsController.innerPadding,
                      top: t.y + PageTextsController.innerPadding,
                      width: t.width - PageTextsController.innerPadding * 2,
                      child: Text(
                        t.text,
                        style: TextStyle(
                          fontSize: t.fontSize,
                          height: 1.25,
                          color: Color(
                            PaperColors.inkFor(t.colorValue, darkPaper: dark),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: CommittedInkLayer(
                      controller: s.controller,
                      darkPaper: dark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // More actions
  // ------------------------------------------------------------

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
      if (!_busy)
        (value: 'copy', icon: Icons.copy_outlined, label: 'Copy page'),
      if (!_busy && _pageClip != null)
        (
          value: 'paste',
          icon: Icons.content_paste_outlined,
          label: 'Paste page',
        ),
      if (!_busy)
        (
          value: 'imagepages',
          icon: Icons.add_photo_alternate_outlined,
          label: 'Add images as pages',
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
                  onTap: () {
                    Navigator.of(sheet).pop(item.value);
                  },
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

      case 'copy':
        _copyPage();

      case 'paste':
        unawaited(_pastePage());

      case 'imagepages':
        unawaited(_addImagePages());

      case 'delete':
        unawaited(_deletePage());

      case 'export':
        unawaited(exportPdf(widget.title));

      case 'settings':
        unawaited(context.push(AppRoutes.settings));
    }
  }

  // ------------------------------------------------------------
  // Paper
  // ------------------------------------------------------------

  bool _darkPaper(_PageSession s) =>
      Theme.of(context).brightness == Brightness.dark;

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
            cacheWidth: 2048,
            filterQuality: FilterQuality.high,
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
        child: PdfPageLayer(
          key: ValueKey('pdf-${session.index}'),
          document: pdf,
          pageNumber: session.index + 1,
          transform: _transform,
          scale: _scale,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Page canvas
  // ------------------------------------------------------------

  Widget _buildPage(_PageSession session) {
    final dark = _darkPaper(session);

    return SizedBox(
      width: kCellSize.width,
      height: kCellSize.height,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _setActive(session.index);
        },
        child: DrawingSurface(
          controller: session.controller,
          allowTouch: _fingerDraws,
          origin: kPaperOrigin,
          isClaimed: (point) {
            if (_textMode) return true;

            final selectTool = session.controller.tool == StrokeTool.select;

            final textHit = session.texts.claims(
              point,
              selectToolActive: selectTool,
            );

            final imageHit =
                !textHit &&
                session.images.claims(point, selectToolActive: selectTool);

            if (!textHit) {
              session.texts.select(null);
            }

            if (!imageHit) {
              session.images.select(null);
            }

            return textHit || imageHit;
          },
          onTap: (point) {
            final t = session.controller.tool;
            if (t != StrokeTool.pen && t != StrokeTool.highlighter) {
              return false;
            }
            if (session.controller.selectAt(
              point.dx,
              point.dy,
              shapesOnly: true,
              duringStroke: true,
            )) {
              session.images.select(null);
              session.texts.select(null);
              _setActive(session.index);
              return true;
            }
            final img = session.images.imageAt(point);
            if (img == null) return false;
            session.images.select(img.id);
            return true;
          },
          onLongPress: (paper, global) =>
              _showPasteMenu(session, paper, global),
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
                child: TextLayer(
                  controller: session.texts,
                  drawing: session.controller,
                  scale: _scale,
                  origin: kPaperOrigin,
                  textMode: _textMode,
                  darkPaper: dark,
                  onCreate: (p) {
                    _createText(session, p);
                  },
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
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: SelectionLayer(
                  controller: session.controller,
                  origin: kPaperOrigin,
                  darkPaper: dark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Paste menu (long press)
  // ------------------------------------------------------------

  Future<void> _showPasteMenu(
    _PageSession session,
    Offset paper,
    Offset global,
  ) async {
    if (_busy || !DrawingController.hasClipboard) return;
    unawaited(HapticFeedback.mediumImpact());
    final v = await showGlassMenu<String>(
      context: context,
      position: global,
      items: const [
        GlassMenuItem(
          value: 'paste',
          icon: Icons.content_paste_outlined,
          label: 'Paste',
        ),
      ],
    );
    if (v == 'paste' && mounted) {
      _setActive(session.index);
      session.controller.pasteAt(paper.dx, paper.dy);
    }
  }

  // ------------------------------------------------------------
  // Shape conversion
  // ------------------------------------------------------------

  static IconData _shapeIcon(ShapeChoice s) => switch (s) {
    ShapeChoice.circle => Icons.circle_outlined,
    ShapeChoice.square => Icons.crop_square,
    ShapeChoice.rectangle => Icons.rectangle_outlined,
    ShapeChoice.ellipse => Icons.egg_outlined,
    ShapeChoice.triangle => Icons.change_history_outlined,
  };

  Future<void> _showShapeMenu(DrawingController c, Offset anchor) async {
    final choice = await showGlassMenu<Object>(
      context: context,
      position: anchor,
      items: [
        if (c.canHighlightSelection)
          GlassMenuItem<Object>(
            value: _highlightAction,
            iconAsset: ToolIcons.highlighter,
            label: 'Highlight',
          ),
        if (c.canRecolorSelection)
          const GlassMenuItem<Object>(
            value: _colorAction,
            icon: Icons.palette_outlined,
            label: 'Change color',
          ),
        if (c.canConvertSelection)
          for (final s in ShapeChoice.values)
            GlassMenuItem<Object>(
              value: s,
              icon: _shapeIcon(s),
              label: s.label,
            ),
      ],
    );
    if (!mounted) return;
    if (choice == _highlightAction) {
      final color = await showGlassDialog<int>(
        context: context,
        builder: (_) => _ShapeColorDialog(
          title: 'Highlight color',
          current: c.selectionFillColorValue,
          allowRemove: c.selectionHighlighted,
        ),
      );
      if (color == null || !mounted) return;
      if (color == _removeFill) {
        c.removeSelectionHighlight();
      } else {
        c.highlightSelection(color);
      }
    } else if (choice == _colorAction) {
      final color = await showGlassDialog<int>(
        context: context,
        builder: (_) => _ShapeColorDialog(
          title: 'Change color',
          current: c.selectionColorValue,
        ),
      );
      if (color != null && mounted) c.changeSelectionColor(color);
    } else if (choice is ShapeChoice) {
      c.convertSelectionTo(choice);
    }
  }

  // ------------------------------------------------------------
  // Selection action bar
  // ------------------------------------------------------------

  Widget _selectionBar() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _transform,
        for (final s in _sessions) s.controller,
      ]),
      builder: (context, _) {
        _PageSession? owner;
        for (final s in _sessions) {
          if (s.controller.hasSelection) {
            owner = s;
            break;
          }
        }
        if (owner == null || _busy) return const SizedBox.shrink();

        final c = owner.controller;
        final f = c.selectionFrame;
        if (f == null || c.isDrawing || c.isTransformingSelection) {
          return const SizedBox.shrink();
        }

        final m = _transform.value;
        final k = m.storage[0];
        final o = _paperOrigin(owner.index);
        final pad = c.framePadDoc;

        final left = (o.dx + f.left - pad) * k + m.storage[12];
        final right = (o.dx + f.right + pad) * k + m.storage[12];
        final top = (o.dy + f.top - pad) * k + m.storage[13];
        final bottom = (o.dy + f.bottom + pad) * k + m.storage[13];

        final paste = DrawingController.hasClipboard;
        final canMore =
            c.canConvertSelection ||
            c.canHighlightSelection ||
            c.canRecolorSelection;
        final w = SelectionActionBar.widthFor(paste: paste, more: canMore);
        const h = SelectionActionBar.height;
        const gap = 18.0;
        const minY = 72.0;

        final x = ((left + right) / 2 - w / 2)
            .clamp(8.0, math.max(8.0, _viewportW - w - 24))
            .toDouble();
        var y = top - h - gap;
        if (y < minY) y = bottom + gap;
        y = y.clamp(minY, math.max(minY, _viewportH - h - 8)).toDouble();

        return Stack(
          children: [
            Positioned(
              left: x,
              top: y,
              child: SelectionActionBar(
                onCopy: c.copySelection,
                onDuplicate: c.duplicateSelection,
                onDelete: c.deleteSelection,
                onPaste: paste ? c.pasteClipboard : null,
                onMore: canMore
                    ? (anchor) => unawaited(_showShapeMenu(c, anchor))
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // Main UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
              children: [
                for (var i = 0; i < _sessions.length; i++)
                  KeyedSubtree(
                    key: ObjectKey(_sessions[i]),
                    child: (i >= _firstVisible && i <= _lastVisible)
                        ? _buildPage(_sessions[i])
                        : SizedBox.fromSize(size: kCellSize),
                  ),
              ],
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
      for (final s in _sessions) s.texts,
      _measure,
    ]);

    // ----------------------------------------------------------
    // Updated canvas with double-tap gestures and scrollbars
    // ----------------------------------------------------------

    final fitCanvas = TwoFingerDoubleTap(
      onDoubleTap: _fitToWidth,
      child: Stack(
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

                        _fitted ? _keepCentered() : _fitWidth();
                      });
                    }

                    return Stack(
                      children: [
                        TwoFingerScrollGuard(
                          zoomEnabled: _zoomAllowed,
                          scrolling: _twoFingerScroll,
                          onScroll: _scrollByFingers,
                          onScrollEnd: _flingByFingers,
                          child: ListenableBuilder(
                            listenable: anyDrawing,
                            child: pages,
                            builder: (context, child) {
                              final busyInput =
                                  _sessions.any(
                                    (s) =>
                                        s.controller.isDrawing ||
                                        s.images.interacting ||
                                        s.texts.interacting,
                                  ) ||
                                  _measure.interacting;

                              return ListenableBuilder(
                                listenable: Listenable.merge([
                                  _zoomAllowed,
                                  _twoFingerScroll,
                                  StylusGate.active,
                                ]),
                                child: child,
                                builder: (context, pagesChild) =>
                                    InteractiveViewer(
                                      transformationController: _transform,
                                      constrained: false,
                                      alignment: Alignment.topLeft,
                                      minScale: _minScale,
                                      maxScale: _maxScale,
                                      scaleFactor: 1000,
                                      boundaryMargin: const EdgeInsets.all(
                                        double.infinity,
                                      ),
                                      panEnabled:
                                          !busyInput &&
                                          !_twoFingerScroll.value &&
                                          !StylusGate.active.value,
                                      scaleEnabled:
                                          _zoomAllowed.value &&
                                          !StylusGate.active.value,
                                      onInteractionStart: (_) {
                                        _view.stop();
                                      },
                                      child: pagesChild!,
                                    ),
                              );
                            },
                          ),
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
                return _scrollbars();
              },
            ),
          ),
          Positioned.fill(child: _selectionBar()),
        ],
      ),
    );

    final canvas = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: StylusGate.down,
      onPointerHover: StylusGate.hover,
      onPointerUp: StylusGate.end,
      onPointerCancel: StylusGate.end,
      child: OneFingerDoubleTap(
        onDoubleTap: () {
          _active.undo();
          unawaited(HapticFeedback.selectionClick());
        },
        child: fitCanvas,
      ),
    );

    // ----------------------------------------------------------
    // Floating toolbar
    // ----------------------------------------------------------

    final toolbar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingToolbar(
          controller: _active,
          fingerDraws: _fingerDraws,
          onFingerDrawsChanged: (v) {
            setState(() => _fingerDraws = v);
          },
          busy: _busy,
          onBack: () {
            context.canPop() ? context.pop() : context.go(AppRoutes.library);
          },
          onPages: _showPages,
          onExport: () {
            unawaited(exportPdf(widget.title));
          },
          onImportPdf: () {
            unawaited(_importPdf());
          },
          onInsertImage: () {
            unawaited(_insertImage());
          },
          onAddPage: () {
            unawaited(_addPageSameTemplate());
          },
          onAddTemplate: () {
            unawaited(_addPage());
          },
          onToggleMeasure: _toggleMeasure,
          onSettings: () {
            context.push(AppRoutes.settings);
          },
          onDuplicatePage: () {
            unawaited(_duplicatePage());
          },
          onDeletePage: _sessions.length > 1
              ? () {
                  unawaited(_deletePage());
                }
              : null,
          onCopyPage: _copyPage,
          onPastePage: _pageClip == null
              ? null
              : () {
                  unawaited(_pastePage());
                },
          textActive: _textMode,
          onTextTool: _toggleTextTool,
          onToolPicked: () {
            _setTextMode(false);
          },
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
      onPrevious: () {
        _scrollToPage(_visiblePage - 1);
      },
      onNext: () {
        _scrollToPage(_visiblePage + 1);
      },
      onAdd: () {
        unawaited(_addPageSameTemplate());
      },
      onAddTemplate: () {
        unawaited(_addPage());
      },
      onAddImage: () {
        unawaited(_insertImage());
      },
      onImport: () {
        unawaited(_importPdf());
      },
      onMore: () {
        unawaited(_showMoreSheet());
      },
    );
  }
}

class _PasteDestinationDialog extends StatefulWidget {
  const _PasteDestinationDialog({required this.count, required this.current});

  final int count;
  final int current;

  @override
  State<_PasteDestinationDialog> createState() =>
      _PasteDestinationDialogState();
}

class _PasteDestinationDialogState extends State<_PasteDestinationDialog> {
  late int _target = widget.current + 1;

  void _set(int v) => setState(() => _target = v.clamp(0, widget.count));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget chip(String label, int value) => ChoiceChip(
      label: Text(label),
      selected: _target == value,
      onSelected: (_) => _set(value),
    );

    return GlassDialog(
      title: const Text('Paste page'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Position', style: text.titleSmall),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Earlier',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _target > 0 ? () => _set(_target - 1) : null,
              ),
              SizedBox(
                width: 160,
                child: Text(
                  'Page ${_target + 1} of ${widget.count + 1}',
                  textAlign: TextAlign.center,
                  style: text.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Later',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _target < widget.count
                    ? () => _set(_target + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('First', 0),
              chip('Before current', widget.current),
              chip('After current', widget.current + 1),
              chip('Last', widget.count),
            ],
          ),
        ],
      ),
      actions: [
        GlassButton(
          label: 'Cancel',
          kind: GlassButtonKind.plain,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassButton(
          autofocus: true,
          label: 'Paste',
          onPressed: () => Navigator.of(context).pop(_target),
        ),
      ],
    );
  }
}

class _PaperClipper extends CustomClipper<Rect> {
  const _PaperClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(kBleedX, kBleedY, kPageSize.width, kPageSize.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class _ShapeColorDialog extends StatelessWidget {
  const _ShapeColorDialog({
    required this.title,
    this.current,
    this.allowRemove = false,
  });

  final String title;
  final int? current;
  final bool allowRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GlassDialog(
      title: Text(title),
      content: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final ink in kInkColors)
            Semantics(
              button: true,
              selected: ink.value == current,
              label: ink.name,
              child: Tooltip(
                message: ink.name,
                child: InkResponse(
                  radius: 28,
                  onTap: () => Navigator.of(context).pop(ink.value),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(ink.value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ink.value == current
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: ink.value == current ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        if (allowRemove)
          GlassButton(
            label: 'Remove',
            kind: GlassButtonKind.destructive,
            onPressed: () => Navigator.of(context).pop(0),
          ),
        GlassButton(
          label: 'Cancel',
          kind: GlassButtonKind.plain,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
