import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../editor/domain/page_image.dart';
import '../../editor/domain/page_repository.dart';
import '../../editor/domain/stroke.dart';
import '../../editor/domain/stroke_tool.dart';

class ExportService {
  ExportService(this._pages);

  final PageRepository _pages;

  static const double _s = 0.75; // 96 dpi pixels -> PDF points
  static const double _w = 794 * _s;
  static const double _h = 1123 * _s;

  Future<File> exportNotebookPdf({
    required String notebookId,
    required String title,
  }) async {
    final count = math.max(1, await _pages.pageCount(notebookId));
    final doc = pw.Document();

    for (var i = 0; i < count; i++) {
      final strokes = await _pages.loadStrokes(notebookId, pageIndex: i);
      final imagePath = await _pages.loadImagePath(notebookId, pageIndex: i);
      final image = imagePath != null && File(imagePath).existsSync()
          ? pw.MemoryImage(await File(imagePath).readAsBytes())
          : null;

      final overlays = <pw.Widget>[];
      for (final img in await _pages.loadImages(notebookId, pageIndex: i)) {
        final file = File(img.path);
        if (!file.existsSync()) continue;
        overlays.add(
          pw.Positioned(
            left: img.x * _s,
            top: img.y * _s,
            child: pw.SizedBox(
              width: img.width * _s,
              height: img.height * _s,
              child: pw.Image(
                pw.MemoryImage(await file.readAsBytes()),
                fit: pw.BoxFit.fill,
              ),
            ),
          ),
        );
      }

      for (final t in await _pages.loadTexts(notebookId, pageIndex: i)) {
        if (t.text.trim().isEmpty) continue;
        overlays.add(
          pw.Positioned(
            left: (t.x + 6) * _s,
            top: (t.y + 6) * _s,
            child: pw.SizedBox(
              width: (t.width - 12) * _s,
              child: pw.Text(
                t.text,
                style: pw.TextStyle(
                  fontSize: t.fontSize * _s,
                  color: PdfColor.fromInt(
                    0xFF000000 | (t.colorValue & 0xFFFFFF),
                  ),
                ),
                textAlign: switch (t.align) {
                  1 => pw.TextAlign.center,
                  2 => pw.TextAlign.right,
                  _ => pw.TextAlign.left,
                },
              ),
            ),
          ),
        );
      }

      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(_w, _h),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              if (image != null)
                pw.Positioned.fill(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ...overlays,
              pw.CustomPaint(
                size: const PdfPoint(_w, _h),
                painter: (canvas, size) => _paint(canvas, size, strokes),
              ),
            ],
          ),
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(dir.path, '$safe.pdf'));
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  void _paint(PdfGraphics canvas, PdfPoint size, List<Stroke> strokes) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final highlighter = stroke.tool == StrokeTool.highlighter;
      final color = PdfColor.fromInt(
        0xFF000000 | (stroke.colorValue & 0xFFFFFF),
      );
      final width = stroke.width * (highlighter ? 6 : 1) * _s;

      canvas.saveContext();
      canvas.setGraphicState(PdfGraphicState(opacity: highlighter ? 0.35 : 1));

      if (stroke.points.length == 1) {
        final pt = stroke.points.first;
        canvas.setFillColor(color);
        canvas.drawEllipse(pt.x * _s, size.y - pt.y * _s, width / 2, width / 2);
        canvas.fillPath();
      } else {
        canvas.setStrokeColor(color);
        canvas.setLineWidth(width);
        canvas.setLineCap(PdfLineCap.round);
        canvas.setLineJoin(PdfLineJoin.round);
        final first = stroke.points.first;
        canvas.moveTo(first.x * _s, size.y - first.y * _s);
        for (final pt in stroke.points.skip(1)) {
          canvas.lineTo(pt.x * _s, size.y - pt.y * _s);
        }
        canvas.strokePath();
      }
      canvas.restoreContext();
    }
  }
}