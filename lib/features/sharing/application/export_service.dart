import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as rx;

import '../../editor/domain/page_repository.dart';
import '../../editor/presentation/drawing/ink_renderer.dart';
import '../../editor/presentation/paper/paper_colors.dart';
import '../../editor/presentation/paper/paper_painter.dart';
import '../../library/domain/paper_template.dart';
import '../domain/export_options.dart';

class ExportService {
  ExportService(this._pages);

  final PageRepository _pages;

  /// Raster pixels per document unit (288 dpi).
  static const double _scale = 3;

  /// A4 in PDF points (same aspect as kPageSize).
  static const double _pdfW = 794 * 0.75;
  static const double _pdfH = 1123 * 0.75;

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

      final doc = pw.Document();
      for (var i = 0; i < count; i++) {
        final png = await _renderPage(
          notebookId: notebookId,
          index: i,
          notebookTemplate: template,
          options: options,
          sourcePage: source?.pages[i],
        );
        final image = pw.MemoryImage(png);
        doc.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(_pdfW, _pdfH),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(image, fit: pw.BoxFit.fill),
            ),
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

  Future<Uint8List> _renderPage({
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

    final owned = <ui.Image>[];
    try {
      ui.Image? background;
      if (sourcePage != null) {
        background = await _renderPdfPage(sourcePage);
      } else if (bgPath != null) {
        background = await _decode(bgPath);
      }
      if (background != null) owned.add(background);

      // Same rule as the editor: backgrounds and PDFs are never darkened.
      final dark =
          options.colorMode == ExportColorMode.dark && background == null;

      const size = kPageSize;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(_scale);

      if (background != null) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFFFFFFFF),
        );
        _drawContained(canvas, background, size);
      } else {
        PaperPainter(template, dark: dark).paint(canvas, size);
      }

      canvas
        ..save()
        ..clipRect(Offset.zero & size);

      for (final img in images) {
        final decoded = await _decode(img.path);
        if (decoded == null) continue;
        owned.add(decoded);
        canvas.drawImageRect(
          decoded,
          Rect.fromLTWH(
            0,
            0,
            decoded.width.toDouble(),
            decoded.height.toDouble(),
          ),
          Rect.fromLTWH(img.x, img.y, img.width, img.height),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }

      for (final t in texts) {
        if (t.text.trim().isEmpty) continue;
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
        painter.paint(canvas, Offset(t.x + 6, t.y + 6));
        painter.dispose();
      }

      for (final s in strokes) {
        InkRenderer.paintStroke(
          canvas,
          points: s.points,
          tool: s.tool,
          colorValue: PaperColors.inkFor(s.colorValue, darkPaper: dark),
          width: s.width,
        );
      }
      canvas.restore();

      final picture = recorder.endRecording();
      final raster = await picture.toImage(
        (size.width * _scale).round(),
        (size.height * _scale).round(),
      );
      picture.dispose();
      try {
        final data = await raster.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('Could not encode page $index.');
        return data.buffer.asUint8List();
      } finally {
        raster.dispose();
      }
    } finally {
      for (final image in owned) {
        image.dispose();
      }
    }
  }

  Future<ui.Image?> _decode(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  /// Renders the PDF page at the size it occupies on screen (contain-fit).
  Future<ui.Image?> _renderPdfPage(rx.PdfPage page) async {
    final fit = applyBoxFit(
      BoxFit.contain,
      Size(page.width, page.height),
      kPageSize,
    ).destination;
    final pixels = await page.render(
      fullWidth: fit.width * _scale,
      fullHeight: fit.height * _scale,
    );
    if (pixels == null) return null;
    try {
      return await pixels.createImage();
    } finally {
      pixels.dispose();
    }
  }

  void _drawContained(Canvas canvas, ui.Image image, Size box) {
    final src = Size(image.width.toDouble(), image.height.toDouble());
    final fit = applyBoxFit(BoxFit.contain, src, box).destination;
    final dst = Alignment.center.inscribe(fit, Offset.zero & box);
    canvas.drawImageRect(
      image,
      Offset.zero & src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }
}
