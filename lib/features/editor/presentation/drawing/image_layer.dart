import 'dart:io';

import 'package:flutter/material.dart';

import '../../application/drawing_controller.dart';
import '../../application/page_images_controller.dart';
import '../../domain/page_image.dart';
import '../../domain/stroke_tool.dart';

const Color _accent = Color(0xFF0A84FF);

/// Images of one page with a selection border, four corner resize handles
/// and a delete button. Place it inside the page cell, below the ink layers.
/// [origin] is the paper corner inside the cell. [scale] returns the zoom.
///
/// An image is grabbed when it is selected, or when the select tool is
/// active. Every other touch passes through, so drawing over images works.
class ImageLayer extends StatelessWidget {
  const ImageLayer({
    super.key,
    required this.controller,
    required this.drawing,
    required this.scale,
    this.origin = Offset.zero,
  });

  final PageImagesController controller;
  final DrawingController drawing;
  final double Function() scale;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, drawing.settings]),
      builder: (context, _) {
        final selectActive = drawing.tool == StrokeTool.select;
        return Stack(
          children: [
            for (final image in controller.images)
              _ImageItem(
                key: ValueKey(image.id),
                image: image,
                controller: controller,
                origin: origin,
                scale: scale,
                selected: image.id == controller.selectedId,
                selectToolActive: selectActive,
              ),
          ],
        );
      },
    );
  }
}

class _ImageItem extends StatelessWidget {
  const _ImageItem({
    super.key,
    required this.image,
    required this.controller,
    required this.origin,
    required this.scale,
    required this.selected,
    required this.selectToolActive,
  });

  final PageImage image;
  final PageImagesController controller;
  final Offset origin;
  final double Function() scale;
  final bool selected;
  final bool selectToolActive;

  static const double _pad = PageImagesController.handleReach;
  static const double _handleBox = _pad * 2;

  @override
  Widget build(BuildContext context) {
    final grabbable = selected || selectToolActive;

    Widget handle(ImageCorner corner) => _CornerHandle(
      corner: corner,
      onStart: controller.beginInteraction,
      onResize: (d) {
        final s = scale();
        controller.resizeBy(image.id, corner, d.dx / s, d.dy / s);
      },
      onEnd: controller.endInteraction,
    );

    // The box is larger than the image so the corner handles stay inside it
    // and can be hit-tested.
    return Positioned(
      left: origin.dx + image.x - _pad,
      top: origin.dy + image.y - _pad,
      width: image.width + _pad * 2,
      height: image.height + _pad * 2,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_pad),
              child: IgnorePointer(
                ignoring: !grabbable,
                child: _PointerDrag(
                  onStart: () {
                    controller.select(image.id);
                    controller.beginInteraction();
                  },
                  onDelta: (d) {
                    final s = scale();
                    controller.moveBy(image.id, d.dx / s, d.dy / s);
                  },
                  onEnd: controller.endInteraction,
                  child: _Picture(path: image.path, selected: selected),
                ),
              ),
            ),
          ),
          if (selected) ...[
            Positioned(
              left: 0,
              top: 0,
              width: _handleBox,
              height: _handleBox,
              child: handle(ImageCorner.topLeft),
            ),
            Positioned(
              right: 0,
              top: 0,
              width: _handleBox,
              height: _handleBox,
              child: handle(ImageCorner.topRight),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              width: _handleBox,
              height: _handleBox,
              child: handle(ImageCorner.bottomLeft),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              width: _handleBox,
              height: _handleBox,
              child: handle(ImageCorner.bottomRight),
            ),
            if (image.width >= 96)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: _pad + 8),
                    child: _DeleteButton(onPressed: controller.deleteSelected),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.path, required this.selected});

  final String path;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Image',
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: selected ? Border.all(color: _accent, width: 1.5) : null,
        ),
        child: Image.file(
          File(path),
          fit: BoxFit.fill,
          cacheWidth: 2400,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0x22000000),
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }
}

class _CornerHandle extends StatelessWidget {
  const _CornerHandle({
    required this.corner,
    required this.onStart,
    required this.onResize,
    required this.onEnd,
  });

  final ImageCorner corner;
  final VoidCallback onStart;
  final ValueChanged<Offset> onResize;
  final VoidCallback onEnd;

  MouseCursor get _cursor =>
      corner == ImageCorner.topLeft || corner == ImageCorner.bottomRight
      ? SystemMouseCursors.resizeUpLeftDownRight
      : SystemMouseCursors.resizeUpRightDownLeft;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Resize image',
      child: _PointerDrag(
        cursor: _cursor,
        onStart: onStart,
        onDelta: onResize,
        onEnd: onEnd,
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Delete image',
      child: Material(
        color: const Color(0xCC000000),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox(
            width: 32,
            height: 32,
            child: Icon(Icons.delete_outline, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Follows one pointer and reports its movement in screen pixels.
class _PointerDrag extends StatefulWidget {
  const _PointerDrag({
    required this.onStart,
    required this.onDelta,
    required this.onEnd,
    required this.child,
    this.cursor = SystemMouseCursors.move,
  });

  final VoidCallback onStart;
  final ValueChanged<Offset> onDelta;
  final VoidCallback onEnd;
  final Widget child;
  final MouseCursor cursor;

  @override
  State<_PointerDrag> createState() => _PointerDragState();
}

class _PointerDragState extends State<_PointerDrag> {
  int? _pointer;

  void _release(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_pointer != null) return;
          _pointer = e.pointer;
          widget.onStart();
        },
        onPointerMove: (e) {
          if (e.pointer == _pointer) widget.onDelta(e.delta);
        },
        onPointerUp: (e) => _release(e.pointer),
        onPointerCancel: (e) => _release(e.pointer),
        child: widget.child,
      ),
    );
  }
}