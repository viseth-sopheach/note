import 'package:flutter/material.dart';

import '../../../library/domain/paper_template.dart';
import 'paper_painter.dart';

/// One white page with its template. Static, so it gets its own raster layer.
class PaperView extends StatelessWidget {
  const PaperView({super.key, required this.template});

  final PaperTemplate template;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
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
          child: CustomPaint(painter: PaperPainter(template)),
        ),
      ),
    );
  }
}
