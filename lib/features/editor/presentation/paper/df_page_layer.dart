import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import 'paper_painter.dart';

/// Draws one PDF page and re-renders it sharper as the user zooms in.
class PdfPageLayer extends StatefulWidget {
  const PdfPageLayer({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.transform,
    required this.scale,
  });

  final PdfDocument document;
  final int pageNumber;
  final Listenable transform;
  final double Function() scale;

  @override
  State<PdfPageLayer> createState() => _PdfPageLayerState();
}

class _PdfPageLayerState extends State<PdfPageLayer> {
  /// Longest side in pixels. Keeps GPU memory bounded.
  static const double _maxSide = 6000;

  ui.Image? _image;
  int _renderedWidth = 0;
  int _token = 0;
  Timer? _debounce;

  PdfPage get _page => widget.document.pages[widget.pageNumber - 1];

  Size get _fit => applyBoxFit(
    BoxFit.contain,
    Size(_page.width, _page.height),
    kPageSize,
  ).destination;

  @override
  void initState() {
    super.initState();
    widget.transform.addListener(_schedule);
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  @override
  void didUpdateWidget(PdfPageLayer old) {
    super.didUpdateWidget(old);
    if (old.pageNumber != widget.pageNumber ||
        old.document != widget.document) {
      _renderedWidth = 0;
      _render();
    }
  }

  @override
  void dispose() {
    _token++;
    _debounce?.cancel();
    widget.transform.removeListener(_schedule);
    _image?.dispose();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _render);
  }

  Future<void> _render() async {
    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final fit = _fit;
    final wanted = fit.width * widget.scale() * dpr;
    // Skip when the current bitmap is already sharp enough.
    if (_renderedWidth >= wanted && _renderedWidth <= wanted * 2.5) return;

    final k = math.min(
      1.0,
      _maxSide /
          math.max(fit.width, fit.height) /
          math.max(1.0, wanted / fit.width),
    );
    final width = math
        .max(fit.width * dpr, wanted)
        .clamp(1, _maxSide)
        .toDouble();
    final height = width * fit.height / fit.width;
    final token = ++_token;
    final page = _page;

    final pixels = await page.render(fullWidth: width, fullHeight: height);
    if (pixels == null) return;
    ui.Image image;
    try {
      image = await pixels.createImage();
    } finally {
      pixels.dispose();
    }
    if (!mounted || token != _token) {
      image.dispose();
      return;
    }
    final old = _image;
    setState(() {
      _image = image;
      _renderedWidth = image.width;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final fit = _fit;
    return Center(
      child: SizedBox(
        width: fit.width,
        height: fit.height,
        child: _image == null
            ? const ColoredBox(color: Color(0xFFFFFFFF))
            : RawImage(
                image: _image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
      ),
    );
  }
}
