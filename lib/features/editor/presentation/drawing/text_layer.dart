import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/drawing_controller.dart';
import '../../application/page_texts_controller.dart';
import '../../domain/page_text.dart';
import '../../domain/stroke_tool.dart';
import '../paper/paper_colors.dart';
import '../toolbar/ink_palette.dart';

const Color _accent = Color(0xFF6366F1);
const Color _ink = Color(0xFF374151);
const List<double> _sizes = [14, 16, 18, 20, 24, 28, 32, 40, 48];
const double _toolbarW = 304;
const double _toolbarH = 44;
const double _inner = PageTextsController.innerPadding;
const Duration _fast = Duration(milliseconds: 130);

TextAlign _alignOf(int a) => switch (a) {
  1 => TextAlign.center,
  2 => TextAlign.right,
  _ => TextAlign.left,
};

double _neededHeight(PageText t, {String? text, double? fontSize}) {
  final value = text ?? t.text;
  final measured = value.isEmpty
      ? ' '
      : (value.endsWith('\n') ? '$value ' : value);
  final painter = TextPainter(
    text: TextSpan(
      text: measured,
      style: TextStyle(fontSize: fontSize ?? t.fontSize, height: 1.25),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: math.max(1.0, t.width - _inner * 2));
  final h = painter.height + _inner * 2;
  painter.dispose();
  return h;
}

/// Text boxes of one page. Place it inside the page cell, below the ink
/// layers. [origin] is the paper corner inside the cell.
///
/// Tap an unselected box to select it, tap the selected box (or click it a
/// second time = double-click) to edit. While editing, handles are hidden.
class TextLayer extends StatelessWidget {
  const TextLayer({
    super.key,
    required this.controller,
    required this.drawing,
    required this.scale,
    required this.textMode,
    required this.onCreate,
    this.origin = Offset.zero,
    this.darkPaper = false,
  });

  final PageTextsController controller;
  final DrawingController drawing;
  final double Function() scale;
  final bool textMode;
  final ValueChanged<Offset> onCreate;
  final Offset origin;
  final bool darkPaper;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => ListenableBuilder(
        listenable: Listenable.merge([controller, drawing.settings]),
        builder: (context, _) {
          final selectActive = drawing.tool == StrokeTool.select;

          PageText? selected;
          for (final t in controller.texts) {
            if (t.id == controller.selectedId) selected = t;
          }

          Rect? bar;
          if (selected != null && !controller.interacting) {
            var top = origin.dy + selected.y - _toolbarH - 20;
            if (top < 0) top = origin.dy + selected.y + selected.height + 20;
            final left =
                (origin.dx + selected.x + selected.width / 2 - _toolbarW / 2)
                    .clamp(0.0, math.max(0.0, box.maxWidth - _toolbarW))
                    .toDouble();
            bar = Rect.fromLTWH(left, top, _toolbarW, _toolbarH);
          }
          controller.toolbarRect = bar?.shift(-origin);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (textMode)
                Positioned.fill(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.text,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) {
                        if (controller.selectedId != null) {
                          controller.select(null);
                        } else {
                          onCreate(d.localPosition - origin);
                        }
                      },
                    ),
                  ),
                ),
              for (final t in controller.texts)
                _TextItem(
                  key: ValueKey(t.id),
                  text: t,
                  controller: controller,
                  origin: origin,
                  scale: scale,
                  darkPaper: darkPaper,
                  selected: t.id == controller.selectedId,
                  editing: t.id == controller.editingId,
                  grabbable:
                      textMode ||
                      t.id == controller.selectedId ||
                      selectActive,
                ),
              if (bar != null && selected != null)
                Positioned.fromRect(
                  rect: bar,
                  child: _TextToolbar(
                    key: ValueKey('bar-${selected.id}'),
                    text: selected,
                    controller: controller,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TextItem extends StatefulWidget {
  const _TextItem({
    super.key,
    required this.text,
    required this.controller,
    required this.origin,
    required this.scale,
    required this.darkPaper,
    required this.selected,
    required this.editing,
    required this.grabbable,
  });

  final PageText text;
  final PageTextsController controller;
  final Offset origin;
  final double Function() scale;
  final bool darkPaper;
  final bool selected;
  final bool editing;
  final bool grabbable;

  @override
  State<_TextItem> createState() => _TextItemState();
}

class _TextItemState extends State<_TextItem> {
  static const double _pad = PageTextsController.handleReach;
  static const double _grip = _pad * 2;

  late final TextEditingController _input = TextEditingController(
    text: widget.text.text,
  );
  final FocusNode _focus = FocusNode();
  bool _wasSelected = false;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing) _focusLater();
  }

  @override
  void didUpdateWidget(_TextItem old) {
    super.didUpdateWidget(old);
    if (widget.editing && !old.editing) {
      _input.text = widget.text.text;
      _focusLater();
    } else if (!widget.editing && old.editing) {
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _focusLater() {
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.editing) _focus.requestFocus();
    });
  }

  TextStyle _style() {
    final t = widget.text;
    return TextStyle(
      color: Color(
        PaperColors.inkFor(t.colorValue, darkPaper: widget.darkPaper),
      ),
      fontSize: t.fontSize,
      height: 1.25,
    );
  }

  Widget _body() {
    final t = widget.text;
    final style = _style();

    if (!widget.editing) {
      return IgnorePointer(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: double.infinity,
            child: Text(t.text, style: style, textAlign: _alignOf(t.align)),
          ),
        ),
      );
    }

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.controller.select(null);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: _input,
        focusNode: _focus,
        style: style,
        textAlign: _alignOf(t.align),
        cursorColor: _accent,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        onTapOutside: (_) {},
        decoration: InputDecoration.collapsed(
          hintText: 'Type here',
          hintStyle: style.copyWith(color: style.color?.withValues(alpha: 0.4)),
        ),
        onChanged: (v) => widget.controller.setText(
          t.id,
          v,
          neededHeight: _neededHeight(t, text: v),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    final c = widget.controller;
    final showGrips = widget.selected && !widget.editing;

    final Color border = widget.editing
        ? _accent.withValues(alpha: 0.55)
        : widget.selected
        ? _accent
        : !widget.grabbable
        ? Colors.transparent
        : _hover
        ? _accent.withValues(alpha: 0.45)
        : _accent.withValues(alpha: 0.18);

    Widget grip(
      _GripKind kind,
      int fx,
      int fy,
      MouseCursor cursor, {
      double? left,
      double? top,
      double? right,
      double? bottom,
    }) => Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: _grip,
      height: _grip,
      child: _Grip(
        kind: kind,
        cursor: cursor,
        onStart: c.beginInteraction,
        onDelta: (d) {
          final k = widget.scale();
          c.resize(t.id, fx, fy, d.dx / k, d.dy / k);
        },
        onEnd: c.endInteraction,
      ),
    );

    final w = t.width + _pad * 2;
    final h = t.height + _pad * 2;

    return Positioned(
      left: widget.origin.dx + t.x - _pad,
      top: widget.origin.dy + t.y - _pad,
      width: w,
      height: h,
      child: Stack(
        children: [
          if (widget.grabbable)
            Positioned.fill(
              child: MouseRegion(
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Tap on the selected box = edit. Two quick taps on an
                  // unselected box (double-click) = select, then edit.
                  onTap: () {
                    if (_wasSelected && !widget.editing) c.startEditing(t.id);
                  },
                  child: _Drag(
                    onStart: () {
                      _wasSelected = widget.selected;
                      c.select(t.id);
                      c.beginInteraction();
                    },
                    onDelta: (d) {
                      final k = widget.scale();
                      c.moveBy(t.id, d.dx / k, d.dy / k);
                    },
                    onEnd: c.endInteraction,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_pad),
              child: AnimatedContainer(
                duration: _fast,
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: widget.selected && !widget.editing
                      ? _accent.withValues(alpha: 0.04)
                      : null,
                  border: Border.all(
                    color: border,
                    width: widget.editing ? 1 : 1.5,
                  ),
                ),
                child: ClipRect(
                  child: Padding(
                    padding: const EdgeInsets.all(_inner),
                    child: _body(),
                  ),
                ),
              ),
            ),
          ),
          if (showGrips) ...[
            grip(
              _GripKind.corner,
              -1,
              -1,
              SystemMouseCursors.resizeUpLeftDownRight,
              left: 0,
              top: 0,
            ),
            grip(
              _GripKind.corner,
              1,
              -1,
              SystemMouseCursors.resizeUpRightDownLeft,
              right: 0,
              top: 0,
            ),
            grip(
              _GripKind.corner,
              -1,
              1,
              SystemMouseCursors.resizeUpRightDownLeft,
              left: 0,
              bottom: 0,
            ),
            grip(
              _GripKind.corner,
              1,
              1,
              SystemMouseCursors.resizeUpLeftDownRight,
              right: 0,
              bottom: 0,
            ),
            if (t.width >= 120) ...[
              grip(
                _GripKind.horizontal,
                0,
                -1,
                SystemMouseCursors.resizeUpDown,
                left: (w - _grip) / 2,
                top: 0,
              ),
              grip(
                _GripKind.horizontal,
                0,
                1,
                SystemMouseCursors.resizeUpDown,
                left: (w - _grip) / 2,
                bottom: 0,
              ),
            ],
            if (t.height >= 80) ...[
              grip(
                _GripKind.vertical,
                -1,
                0,
                SystemMouseCursors.resizeLeftRight,
                left: 0,
                top: (h - _grip) / 2,
              ),
              grip(
                _GripKind.vertical,
                1,
                0,
                SystemMouseCursors.resizeLeftRight,
                right: 0,
                top: (h - _grip) / 2,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

enum _GripKind { corner, horizontal, vertical }

class _Grip extends StatefulWidget {
  const _Grip({
    required this.kind,
    required this.cursor,
    required this.onStart,
    required this.onDelta,
    required this.onEnd,
  });

  final _GripKind kind;
  final MouseCursor cursor;
  final VoidCallback onStart;
  final ValueChanged<Offset> onDelta;
  final VoidCallback onEnd;

  @override
  State<_Grip> createState() => _GripState();
}

class _GripState extends State<_Grip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final corner = widget.kind == _GripKind.corner;
    final w = corner ? 12.0 : (widget.kind == _GripKind.horizontal ? 24.0 : 8.0);
    final h = corner ? 12.0 : (widget.kind == _GripKind.horizontal ? 8.0 : 24.0);

    return Semantics(
      label: 'Resize text box',
      child: _Drag(
        cursor: widget.cursor,
        onStart: widget.onStart,
        onDelta: widget.onDelta,
        onEnd: widget.onEnd,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Center(
            child: AnimatedScale(
              scale: _hover ? 1.2 : 1,
              duration: _fast,
              child: AnimatedContainer(
                duration: _fast,
                width: w,
                height: h,
                decoration: BoxDecoration(
                  color: _hover ? _accent : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _accent, width: 1.75),
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
        ),
      ),
    );
  }
}

class _TextToolbar extends StatefulWidget {
  const _TextToolbar({super.key, required this.text, required this.controller});

  final PageText text;
  final PageTextsController controller;

  @override
  State<_TextToolbar> createState() => _TextToolbarState();
}

class _TextToolbarState extends State<_TextToolbar> {
  final MenuController _menu = MenuController();

  void _apply({double? size, int? color, int? align}) {
    final t = widget.text;
    widget.controller.setStyle(
      t.id,
      fontSize: size,
      colorValue: color,
      align: align,
      neededHeight: _neededHeight(t, fontSize: size),
    );
  }

  double _step(int dir) {
    final cur = widget.text.fontSize;
    return dir > 0
        ? _sizes.firstWhere((s) => s > cur, orElse: () => _sizes.last)
        : _sizes.lastWhere((s) => s < cur, orElse: () => _sizes.first);
  }

  Widget _sep() => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: const Color(0x1F000000),
  );

  @override
  Widget build(BuildContext context) {
    final t = widget.text;

    Widget align(int value, IconData icon, String tip) => _ToolBtn(
      tooltip: tip,
      selected: t.align == value,
      onTap: () => _apply(align: value),
      child: Icon(
        icon,
        size: 18,
        color: t.align == value ? _accent : _ink,
      ),
    );

    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ToolBtn(
            tooltip: 'Smaller',
            onTap: () => _apply(size: _step(-1)),
            child: const Icon(Icons.remove, size: 18, color: _ink),
          ),
          SizedBox(
            width: 30,
            child: Center(
              child: Text(
                '${t.fontSize.round()}',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _ToolBtn(
            tooltip: 'Larger',
            onTap: () => _apply(size: _step(1)),
            child: const Icon(Icons.add, size: 18, color: _ink),
          ),
          _sep(),
          align(0, Icons.format_align_left, 'Align left'),
          align(1, Icons.format_align_center, 'Align center'),
          align(2, Icons.format_align_right, 'Align right'),
          _sep(),
          MenuAnchor(
            controller: _menu,
            style: const MenuStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
              surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
              shadowColor: WidgetStatePropertyAll(Colors.transparent),
              elevation: WidgetStatePropertyAll(0),
              padding: WidgetStatePropertyAll(EdgeInsets.zero),
            ),
            menuChildren: [
              Material(
                color: Colors.white,
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: 6 * 26 + 5 * 8,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ink in kInkColors)
                          GestureDetector(
                            onTap: () {
                              _apply(color: ink.value);
                              _menu.close();
                            },
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Color(ink.value),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ink.value == t.colorValue
                                      ? _accent
                                      : const Color(0x22000000),
                                  width: ink.value == t.colorValue ? 2.5 : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            builder: (context, menu, _) => _ToolBtn(
              tooltip: 'Text color',
              onTap: () => menu.isOpen ? menu.close() : menu.open(),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Color(t.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x33000000)),
                ),
              ),
            ),
          ),
          _sep(),
          _ToolBtn(
            tooltip: 'Delete',
            onTap: widget.controller.deleteSelected,
            child: const Icon(
              Icons.delete_outline,
              size: 18,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatefulWidget {
  const _ToolBtn({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.selected = false,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;

  @override
  State<_ToolBtn> createState() => _ToolBtnState();
}

class _ToolBtnState extends State<_ToolBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _fast,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.selected
                  ? _accent.withValues(alpha: 0.14)
                  : _hover
                  ? const Color(0x0F000000)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Follows one pointer and reports its movement in screen pixels.
class _Drag extends StatefulWidget {
  const _Drag({
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
  State<_Drag> createState() => _DragState();
}

class _DragState extends State<_Drag> {
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