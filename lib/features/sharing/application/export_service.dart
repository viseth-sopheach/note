import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart'
    show
        PdfColor,
        PdfGraphicState,
        PdfGraphics,
        PdfLineCap,
        PdfLineJoin,
        PdfPageFormat,
        PdfPoint;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as rx;

import '../../editor/domain/page_image.dart';
import '../../editor/domain/page_repository.dart';
import '../../editor/domain/page_text.dart';
import '../../editor/domain/stroke.dart';
import '../../editor/domain/stroke_point.dart';
import '../../editor/domain/stroke_tool.dart';
import '../../editor/presentation/drawing/ink_renderer.dart';
import '../../editor/presentation/paper/paper_colors.dart';
import '../../editor/presentation/paper/paper_painter.dart';
import '../../library/domain/paper_template.dart';
import '../domain/export_options.dart';

/// Exports notebooks as PDFs with vector ink, vector paper and embedded
/// original images. Only PDF backgrounds and text boxes are rasterised.
class ExportService {
  ExportService(this._pages);

  final PageRepository _pages;

  /// Document units (96 dpi) to PDF points (72 dpi).
  static const double _k = 0.75;

  /// Raster pixels per document unit for PDF backgrounds and text boxes.
  static const double _rasterScale = 4;

  static final double _pdfW = kPageSize.width * _k;
  static final double _pdfH = kPageSize.height * _k;

  Future<File> exportNotebookPdf({
    required String notebookId,
    required String title,
    required PaperTemplate template,
    String? pdfPath,
    ExportOptions options = const ExportOptions(),
  }) async {
    rx.PdfDocument? source;
    try {
      if (pdfPath != null) source = await rx.PdfDocument.openFile(pdfPath);
      final count =
          source?.pages.length ??
          math.max(1, await _pages.pageCount(notebookId));

      final doc = pw.Document(compress: true);
      for (var i = 0; i < count; i++) {
        final page = await _buildPage(
          notebookId: notebookId,
          index: i,
          notebookTemplate: template,
          options: options,
          sourcePage: source?.pages[i],
        );
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(_pdfW, _pdfH),
            margin: pw.EdgeInsets.zero,
            build: (_) => page,
          ),
        );
      }

      final dir = await getTemporaryDirectory();
      final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File(p.join(dir.path, '$safe.pdf'));
      await file.writeAsBytes(await doc.save(), flush: true);
      return file;
    } finally {
      source?.dispose();
    }
  }

  // ---------------------------------------------------------------------
  // Page assembly
  // ---------------------------------------------------------------------

  Future<pw.Widget> _buildPage({
    required String notebookId,
    required int index,
    required PaperTemplate notebookTemplate,
    required ExportOptions options,
    rx.PdfPage? sourcePage,
  }) async {
    final strokes = await _pages.loadStrokes(notebookId, pageIndex: index);
    final images = await _pages.loadImages(notebookId, pageIndex: index);
    final texts = await _pages.loadTexts(notebookId, pageIndex: index);
    final bgPath = await _pages.loadImagePath(notebookId, pageIndex: index);
    final template =
        options.paper.template ??
        await _pages.loadTemplate(notebookId, pageIndex: index) ??
        notebookTemplate;

    // Background: rendered PDF page, background image, or vector paper.
    Uint8List? backgroundBytes;
    Size? backgroundSize;
    if (sourcePage != null) {
      final rendered = await _renderPdfPage(sourcePage);
      backgroundBytes = rendered?.bytes;
      backgroundSize = rendered?.size;
    } else if (bgPath != null) {
      final file = File(bgPath);
      if (file.existsSync()) {
        backgroundBytes = await file.readAsBytes();
        backgroundSize = await _imageSize(backgroundBytes);
      }
    }
    final hasBackground = backgroundBytes != null && backgroundSize != null;
    final dark = options.colorMode == ExportColorMode.dark && !hasBackground;

    final children = <pw.Widget>[];

    children.add(
      pw.CustomPaint(
        size: PdfPoint(_pdfW, _pdfH),
        painter: (g, _) => hasBackground
            ? _fillRect(g, const PdfColor(1, 1, 1))
            : _paintPaper(g, template, dark),
      ),
    );

    if (hasBackground) {
      final fit = applyBoxFit(
        BoxFit.contain,
        backgroundSize,
        kPageSize,
      ).destination;
      children.add(
        pw.Positioned(
          left: (kPageSize.width - fit.width) / 2 * _k,
          top: (kPageSize.height - fit.height) / 2 * _k,
          child: pw.Image(
            pw.MemoryImage(backgroundBytes),
            width: fit.width * _k,
            height: fit.height * _k,
            fit: pw.BoxFit.fill,
          ),
        ),
      );
    }

    for (final img in images) {
      final widget = await _imageWidget(img);
      if (widget != null) children.add(widget);
    }

    for (final t in texts) {
      final widget = await _textWidget(t, dark);
      if (widget != null) children.add(widget);
    }

    children.add(
      pw.CustomPaint(
        size: PdfPoint(_pdfW, _pdfH),
        painter: (g, _) => _paintInk(g, strokes, dark),
      ),
    );

    return pw.SizedBox(
      width: _pdfW,
      height: _pdfH,
      child: pw.Stack(children: children),
    );
  }

  // ---------------------------------------------------------------------
  // Vector painting (PDF origin is bottom-left, so y is flipped)
  // ---------------------------------------------------------------------

  static double _x(double v) => v * _k;
  static double _y(double v) => _pdfH - v * _k;

  static PdfColor _pdfColor(int argb) {
    final c = Color(argb);
    return PdfColor(c.r, c.g, c.b);
  }

  void _fillRect(PdfGraphics g, PdfColor color) {
    g
      ..setFillColor(color)
      ..drawRect(0, 0, _pdfW, _pdfH)
      ..fillPath();
  }

  void _paintPaper(PdfGraphics g, PaperTemplate template, bool dark) {
    _fillRect(g, _pdfColor(PaperColors.surfaceFor(dark).toARGB32()));
    final line = _pdfColor(PaperColors.lineFor(dark).toARGB32());
    final w = kPageSize.width;
    final h = kPageSize.height;

    g
      ..setStrokeColor(line)
      ..setFillColor(line)
      ..setLineWidth(1 * _k);

    switch (template) {
      case PaperTemplate.blank:
        break;
      case PaperTemplate.lined:
        for (var y = kPaperMargin + kPaperSpacing; y < h; y += kPaperSpacing) {
          g
            ..moveTo(0, _y(y))
            ..lineTo(_x(w), _y(y))
            ..strokePath();
        }
      case PaperTemplate.grid:
        for (var y = kPaperSpacing; y < h; y += kPaperSpacing) {
          g
            ..moveTo(0, _y(y))
            ..lineTo(_x(w), _y(y))
            ..strokePath();
        }
        for (var x = kPaperSpacing; x < w; x += kPaperSpacing) {
          g
            ..moveTo(_x(x), 0)
            ..lineTo(_x(x), _pdfH)
            ..strokePath();
        }
      case PaperTemplate.dotted:
        for (var y = kPaperSpacing; y < h; y += kPaperSpacing) {
          for (var x = kPaperSpacing; x < w; x += kPaperSpacing) {
            g
              ..drawEllipse(_x(x), _y(y), 1.5 * _k, 1.5 * _k)
              ..fillPath();
          }
        }
    }
  }

  void _paintInk(PdfGraphics g, List<Stroke> strokes, bool dark) {
    g
      ..saveContext()
      ..drawRect(0, 0, _pdfW, _pdfH)
      ..clipPath();

    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final highlighter = s.tool == StrokeTool.highlighter;
      final width =
          (highlighter
              ? s.width * InkRenderer.highlighterWidthScale
              : s.width) *
          _k;
      final color = _pdfColor(
        PaperColors.inkFor(s.colorValue, darkPaper: dark),
      );
      final alpha = highlighter ? InkRenderer.highlighterAlpha : 1.0;

      g
        ..saveContext()
        ..setGraphicState(PdfGraphicState(opacity: alpha, strokeOpacity: alpha))
        ..setStrokeColor(color)
        ..setFillColor(color);

      final pts = s.points;
      if (pts.length == 1) {
        g
          ..drawEllipse(_x(pts.first.x), _y(pts.first.y), width / 2, width / 2)
          ..fillPath();
      } else {
        g
          ..setLineWidth(width)
          ..setLineCap(highlighter ? PdfLineCap.square : PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round);
        _smoothPath(g, pts);
        g.strokePath();
      }
      g.restoreContext();
    }
    g.restoreContext();
  }

  /// Same midpoint-quadratic curve as InkRenderer, written as cubic Béziers.
  void _smoothPath(PdfGraphics g, List<StrokePoint> pts) {
    g.moveTo(_x(pts.first.x), _y(pts.first.y));
    if (pts.length == 2) {
      g.lineTo(_x(pts.last.x), _y(pts.last.y));
      return;
    }
    var cx = pts.first.x;
    var cy = pts.first.y;
    for (var i = 1; i < pts.length - 1; i++) {
      final qx = pts[i].x;
      final qy = pts[i].y;
      final mx = (pts[i].x + pts[i + 1].x) / 2;
      final my = (pts[i].y + pts[i + 1].y) / 2;
      g.curveTo(
        _x(cx + 2 / 3 * (qx - cx)),
        _y(cy + 2 / 3 * (qy - cy)),
        _x(mx + 2 / 3 * (qx - mx)),
        _y(my + 2 / 3 * (qy - my)),
        _x(mx),
        _y(my),
      );
      cx = mx;
      cy = my;
    }
    g.lineTo(_x(pts.last.x), _y(pts.last.y));
  }

  // ---------------------------------------------------------------------
  // Images and text
  // ---------------------------------------------------------------------

  /// Embeds JPEG and PNG files untouched (no quality loss). Other formats
  /// are converted to PNG.
  Future<pw.Widget?> _imageWidget(PageImage img) async {
    final file = File(img.path);
    if (!file.existsSync()) return null;
    final raw = await file.readAsBytes();
    final ext = p.extension(img.path).toLowerCase();

    pw.MemoryImage? image;
    if (const {'.jpg', '.jpeg', '.png'}.contains(ext)) {
      try {
        image = pw.MemoryImage(raw);
      } catch (_) {
        image = null;
      }
    }
    image ??= await _convertToPng(raw);
    if (image == null) return null;

    return pw.Positioned(
      left: img.x * _k,
      top: img.y * _k,
      child: pw.Image(
        image,
        width: img.width * _k,
        height: img.height * _k,
        fit: pw.BoxFit.fill,
      ),
    );
  }

  Future<pw.MemoryImage?> _convertToPng(Uint8List raw) async {
    try {
      final codec = await ui.instantiateImageCodec(raw);
      try {
        final image = (await codec.getNextFrame()).image;
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data == null
              ? null
              : pw.MemoryImage(data.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  /// Text is shaped by Flutter (needed for Khmer) and embedded as a
  /// high-resolution transparent image.
  Future<pw.Widget?> _textWidget(PageText t, bool dark) async {
    if (t.text.trim().isEmpty) return null;
    final width = math.max(1.0, t.width - 12);
    final painter = TextPainter(
      text: TextSpan(
        text: t.text,
        style: TextStyle(
          color: Color(PaperColors.inkFor(t.colorValue, darkPaper: dark)),
          fontSize: t.fontSize,
          height: 1.25,
        ),
      ),
      textAlign: switch (t.align) {
        1 => TextAlign.center,
        2 => TextAlign.right,
        _ => TextAlign.left,
      },
      textDirection: TextDirection.ltr,
    )..layout(minWidth: width, maxWidth: width);

    final h = math.max(1.0, painter.height);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_rasterScale);
    painter.paint(canvas, Offset.zero);
    painter.dispose();

    final picture = recorder.endRecording();
    final raster = await picture.toImage(
      (width * _rasterScale).ceil(),
      (h * _rasterScale).ceil(),
    );
    picture.dispose();
    try {
      final data = await raster.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      return pw.Positioned(
        left: (t.x + 6) * _k,
        top: (t.y + 6) * _k,
        child: pw.Image(
          pw.MemoryImage(data.buffer.asUint8List()),
          width: width * _k,
          height: h * _k,
          fit: pw.BoxFit.fill,
        ),
      );
    } finally {
      raster.dispose();
    }
  }

  // ---------------------------------------------------------------------
  // Backgrounds
  // ---------------------------------------------------------------------

  Future<({Uint8List bytes, Size size})?> _renderPdfPage(
    rx.PdfPage page,
  ) async {
    final fit = applyBoxFit(
      BoxFit.contain,
      Size(page.width, page.height),
      kPageSize,
    ).destination;
    final pixels = await page.render(
      fullWidth: fit.width * _rasterScale,
      fullHeight: fit.height * _rasterScale,
    );
    if (pixels == null) return null;
    try {
      final image = await pixels.createImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) return null;
        return (bytes: data.buffer.asUint8List(), size: fit);
      } finally {
        image.dispose();
      }
    } finally {
      pixels.dispose();
    }
  }

  Future<Size?> _imageSize(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final d = await ui.ImageDescriptor.encoded(buffer);
      try {
        return Size(d.width.toDouble(), d.height.toDouble());
      } finally {
        d.dispose();
      }
    } catch (_) {
      return null;
    } finally {
      buffer.dispose();
    }
  }
}
