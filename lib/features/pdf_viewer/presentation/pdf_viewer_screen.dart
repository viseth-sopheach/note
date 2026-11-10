import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

/// High-fidelity PDF viewer.
///
/// pdfrx renders with PDFium and re-renders the visible area at
/// (zoom x devicePixelRatio), so text and vector math stay sharp when zoomed.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.filePath, this.title});

  final String filePath;
  final String? title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  static const double _maxScale = 16; // 1600%
  static const int _imageCacheBytes = 200 * 1024 * 1024;

  final PdfViewerController _controller = PdfViewerController();
  int _page = 1;
  int _pageCount = 0;

  late final PdfViewerParams _params = PdfViewerParams(
    maxScale: _maxScale,
    minScale: 0.25,
    useAlternativeFitScaleAsMinScale: false,
    // Pages are rendered in one pass up to this scale, then re-rendered
    // as sharp tiles when zoomed beyond it.
    onePassRenderingScaleThreshold: 200 / 72,
    maxImageBytesCachedOnMemory: _imageCacheBytes,
    backgroundColor: const Color(0xFF2A2A2D),
    margin: 8,
    onViewerReady: (document, controller) {
      if (!mounted) return;
      setState(() => _pageCount = document.pages.length);
    },
    onPageChanged: (page) {
      if (page != null && mounted) setState(() => _page = page);
    },
    loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
        const Center(child: CircularProgressIndicator()),
    errorBannerBuilder: (context, error, stackTrace, documentRef) {
      developer.log(
        'PDF load failed',
        name: 'pdf_viewer',
        error: error,
        stackTrace: stackTrace,
      );
      return const Center(child: Text('Could not open this PDF.'));
    },
    viewerOverlayBuilder: (context, size, handleLinkTap) => [
      PdfViewerScrollThumb(
        controller: _controller,
        orientation: ScrollbarOrientation.right,
        thumbSize: const Size(40, 25),
        thumbBuilder: (context, thumbSize, pageNumber, controller) => Material(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              '$pageNumber',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    ],
  );

  Future<void> _zoomIn() => _controller.zoomUp();
  Future<void> _zoomOut() => _controller.zoomDown();

  Future<void> _goTo(int page) async {
    if (page < 1 || page > _pageCount) return;
    await _controller.goToPage(pageNumber: page);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.equal, control: true): _zoomIn,
        const SingleActivator(LogicalKeyboardKey.add, control: true): _zoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            _zoomOut,
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            _goTo(_page + 1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            _goTo(_page - 1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.title ?? 'PDF',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (_pageCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(child: Text('$_page / $_pageCount')),
                ),
              IconButton(
                tooltip: 'Zoom out (Ctrl+-)',
                icon: const Icon(Icons.zoom_out),
                onPressed: _zoomOut,
              ),
              IconButton(
                tooltip: 'Zoom in (Ctrl++)',
                icon: const Icon(Icons.zoom_in),
                onPressed: _zoomIn,
              ),
            ],
          ),
          body: PdfViewer.file(
            widget.filePath,
            controller: _controller,
            params: _params,
          ),
        ),
      ),
    );
  }
}
