import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/glass/glass_button.dart';
import '../../../../app/glass/glass_dialog.dart';
import '../../../../app/glass/glass_theme.dart';

/// Custom color picker: 2D saturation/brightness pad, hue and opacity
/// spectrum sliders, R/G/B/A sliders with number fields, and HEX and
/// RGB/RGBA text fields (with copy). Everything stays in sync.
/// Returns an ARGB int (Color.toARGB32 format), or null if cancelled.
class RgbColorDialog extends StatefulWidget {
  const RgbColorDialog({
    super.key,
    required this.initial,
    this.allowAlpha = true,
  });

  final int initial;
  final bool allowAlpha;

  static Future<int?> show(
    BuildContext context, {
    required int initial,
    bool allowAlpha = true,
  }) => showGlassDialog<int>(
    context: context,
    builder: (_) => RgbColorDialog(initial: initial, allowAlpha: allowAlpha),
  );

  @override
  State<RgbColorDialog> createState() => _RgbColorDialogState();
}

int _ch(double v) => (v * 255).round().clamp(0, 255);

class _RgbColorDialogState extends State<RgbColorDialog> {
  late int _r, _g, _b, _a;
  late double _h, _s, _v;
  bool _hexOk = true;
  bool _rgbaOk = true;
  String? _copied;
  Timer? _copyTimer;

  final _hex = TextEditingController();
  final _rgba = TextEditingController();
  final _rc = TextEditingController();
  final _gc = TextEditingController();
  final _bc = TextEditingController();
  final _ac = TextEditingController();

  static final RegExp _rgbaRe = RegExp(
    r'^rgba?\(\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*'
    r'(?:[,/]\s*([0-9]*\.?[0-9]+)\s*(%?))?\s*\)$',
    caseSensitive: false,
  );

  int get _value => (_a << 24) | (_r << 16) | (_g << 8) | _b;
  Color get _color => Color.fromARGB(_a, _r, _g, _b);

  String get _hexText {
    final rgb = ((_r << 16) | (_g << 8) | _b)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    if (!widget.allowAlpha || _a == 255) return rgb;
    return rgb + _a.toRadixString(16).padLeft(2, '0').toUpperCase();
  }

  String get _alphaText =>
      (_a / 255).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  String get _rgbaText => widget.allowAlpha
      ? 'rgba($_r, $_g, $_b, $_alphaText)'
      : 'rgb($_r, $_g, $_b)';

  @override
  void initState() {
    super.initState();
    final c = Color(widget.initial);
    _r = _ch(c.r);
    _g = _ch(c.g);
    _b = _ch(c.b);
    _a = widget.allowAlpha ? _ch(c.a) : 255;
    final hsv = HSVColor.fromColor(Color.fromARGB(255, _r, _g, _b));
    _h = hsv.hue;
    _s = hsv.saturation;
    _v = hsv.value;
    _syncFields();
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    for (final c in [_hex, _rgba, _rc, _gc, _bc, _ac]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- State changes: every path ends in _syncFields ----

  static void _write(TextEditingController c, String text) {
    if (c.text == text) return;
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// [skip] is the field being typed in; its text is left alone.
  void _syncFields({String? skip}) {
    if (skip != 'hex') _write(_hex, _hexText);
    if (skip != 'rgba') _write(_rgba, _rgbaText);
    if (skip != 'r') _write(_rc, '$_r');
    if (skip != 'g') _write(_gc, '$_g');
    if (skip != 'b') _write(_bc, '$_b');
    if (skip != 'a') _write(_ac, '$_a');
  }

  void _setRgb({int? r, int? g, int? b, int? a, String? source}) {
    setState(() {
      _r = (r ?? _r).clamp(0, 255);
      _g = (g ?? _g).clamp(0, 255);
      _b = (b ?? _b).clamp(0, 255);
      _a = widget.allowAlpha ? (a ?? _a).clamp(0, 255) : 255;
      final hsv = HSVColor.fromColor(Color.fromARGB(255, _r, _g, _b));
      // Grays and black have no defined hue / saturation: keep the old ones.
      if (hsv.saturation > 0 && hsv.value > 0) _h = hsv.hue;
      if (hsv.value > 0) _s = hsv.saturation;
      _v = hsv.value;
      _hexOk = true;
      _rgbaOk = true;
    });
    _syncFields(skip: source);
  }

  void _setHsv({double? h, double? s, double? v}) {
    setState(() {
      _h = (h ?? _h).clamp(0.0, 360.0).toDouble();
      _s = (s ?? _s).clamp(0.0, 1.0).toDouble();
      _v = (v ?? _v).clamp(0.0, 1.0).toDouble();
      final c = HSVColor.fromAHSV(1, _h, _s, _v).toColor();
      _r = _ch(c.r);
      _g = _ch(c.g);
      _b = _ch(c.b);
      _hexOk = true;
      _rgbaOk = true;
    });
    _syncFields();
  }

  void _onNumber(String key, String text) {
    final n = int.tryParse(text);
    if (n == null) return;
    final v = n.clamp(0, 255);
    if (v != n) {
      _write(switch (key) {
        'r' => _rc,
        'g' => _gc,
        'b' => _bc,
        _ => _ac,
      }, '$v');
    }
    _setRgb(
      r: key == 'r' ? v : null,
      g: key == 'g' ? v : null,
      b: key == 'b' ? v : null,
      a: key == 'a' ? v : null,
      source: key,
    );
  }

  void _onHex(String raw) {
    var t = raw.trim();
    if (t.startsWith('#')) t = t.substring(1);
    if (t.length == 3 || t.length == 4) {
      t = t.split('').map((c) => '$c$c').join();
    }
    final n = (t.length == 6 || t.length == 8)
        ? int.tryParse(t, radix: 16)
        : null;
    if (n == null) {
      setState(() => _hexOk = false);
      return;
    }
    if (t.length == 6) {
      _setRgb(
        r: (n >> 16) & 0xFF,
        g: (n >> 8) & 0xFF,
        b: n & 0xFF,
        source: 'hex',
      );
    } else {
      _setRgb(
        r: (n >> 24) & 0xFF,
        g: (n >> 16) & 0xFF,
        b: (n >> 8) & 0xFF,
        a: n & 0xFF,
        source: 'hex',
      );
    }
  }

  void _onRgba(String raw) {
    final m = _rgbaRe.firstMatch(raw.trim());
    if (m == null) {
      setState(() => _rgbaOk = false);
      return;
    }
    int ch(String s) => int.parse(s).clamp(0, 255);
    int? alpha;
    final a = m.group(4);
    if (a != null) {
      var f = double.tryParse(a) ?? 1;
      if (m.group(5) == '%') f /= 100;
      alpha = (f.clamp(0.0, 1.0) * 255).round();
    }
    _setRgb(
      r: ch(m.group(1)!),
      g: ch(m.group(2)!),
      b: ch(m.group(3)!),
      a: alpha ?? (widget.allowAlpha ? 255 : null),
      source: 'rgba',
    );
  }

  void _copy(String key, String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    _copyTimer?.cancel();
    setState(() => _copied = key);
    _copyTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = null);
    });
  }

  // ---- UI ----

  Widget _numberRow(
    String label,
    Color accent,
    int value,
    TextEditingController ctrl,
    String key,
  ) {
    return Row(
      children: [
        SizedBox(width: 16, child: Text(label)),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            divisions: 255,
            value: value.toDouble(),
            activeColor: accent,
            label: '$value',
            onChanged: (v) => _setRgb(
              r: key == 'r' ? v.round() : null,
              g: key == 'g' ? v.round() : null,
              b: key == 'b' ? v.round() : null,
              a: key == 'a' ? v.round() : null,
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: TextField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: const InputDecoration(isDense: true),
            onChanged: (t) => _onNumber(key, t),
            onEditingComplete: _syncFields,
            onTapOutside: (_) => _syncFields(),
          ),
        ),
      ],
    );
  }

  Widget _copyButton(String key, String tooltip, String text) {
    final done = _copied == key;
    return IconButton(
      tooltip: done ? 'Copied' : tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(done ? Icons.check : Icons.copy_outlined, size: 18),
      onPressed: () => _copy(key, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = context.glass.border;
    final opaque = Color.fromARGB(255, _r, _g, _b);
    final alphaOn = widget.allowAlpha;

    return GlassDialog(
      title: const Text('Custom color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview: previous (left) and new (right) over a checkerboard.
          Semantics(
            label: 'Color preview',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: SizedBox(
                  height: 52,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: const _CheckerPainter()),
                      Row(
                        children: [
                          Expanded(
                            child: ColoredBox(color: Color(widget.initial)),
                          ),
                          Expanded(child: ColoredBox(color: _color)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SvPicker(
            hue: _h,
            saturation: _s,
            value: _v,
            onChanged: (s, v) => _setHsv(s: s, v: v),
          ),
          const SizedBox(height: 8),
          _TrackSlider(
            label: 'Hue',
            value: _h / 360,
            thumb: HSVColor.fromAHSV(1, _h, 1, 1).toColor(),
            gradient: LinearGradient(
              colors: [
                for (var i = 0; i <= 6; i++)
                  HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
              ],
            ),
            onChanged: (t) => _setHsv(h: t * 360),
          ),
          if (alphaOn)
            _TrackSlider(
              label: 'Opacity',
              value: _a / 255,
              thumb: _color,
              checker: true,
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(0, _r, _g, _b),
                  Color.fromARGB(255, _r, _g, _b),
                ],
              ),
              onChanged: (t) => _setRgb(a: (t * 255).round()),
            ),
          const SizedBox(height: 4),
          _numberRow('R', Colors.red, _r, _rc, 'r'),
          _numberRow('G', Colors.green, _g, _gc, 'g'),
          _numberRow('B', Colors.blue, _b, _bc, 'b'),
          if (alphaOn) _numberRow('A', scheme.outline, _a, _ac, 'a'),
          const SizedBox(height: 8),
          TextField(
            controller: _hex,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F#]')),
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: InputDecoration(
              labelText: alphaOn ? 'Hex (RRGGBB or RRGGBBAA)' : 'Hex',
              prefixText: '#',
              isDense: true,
              errorText: _hexOk ? null : 'Enter 3, 4, 6 or 8 hex digits',
              suffixIcon: _copyButton('hex', 'Copy HEX', '#$_hexText'),
            ),
            onChanged: _onHex,
            onEditingComplete: _syncFields,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rgba,
            decoration: InputDecoration(
              labelText: alphaOn ? 'RGBA' : 'RGB',
              isDense: true,
              errorText: _rgbaOk ? null : 'Use rgba(r, g, b, a)',
              suffixIcon: _copyButton(
                'rgba',
                alphaOn ? 'Copy RGBA' : 'Copy RGB',
                _rgbaText,
              ),
            ),
            onChanged: _onRgba,
            onEditingComplete: _syncFields,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: opaque, shape: BoxShape.circle),
            ),
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
          label: 'Select',
          onPressed: (_hexOk && _rgbaOk)
              ? () => Navigator.of(context).pop(_value)
              : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Saturation / brightness pad
// ---------------------------------------------------------------------------

class _SvPicker extends StatelessWidget {
  const _SvPicker({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double s, double v) onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Saturation and brightness',
      value:
          '${(saturation * 100).round()}% saturation, '
          '${(value * 100).round()}% brightness',
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, 150);
          void update(Offset p) => onChanged(
            (p.dx / size.width).clamp(0.0, 1.0).toDouble(),
            (1 - p.dy / size.height).clamp(0.0, 1.0).toDouble(),
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => update(d.localPosition),
            onHorizontalDragStart: (d) => update(d.localPosition),
            onHorizontalDragUpdate: (d) => update(d.localPosition),
            onVerticalDragStart: (d) => update(d.localPosition),
            onVerticalDragUpdate: (d) => update(d.localPosition),
            child: CustomPaint(
              size: size,
              painter: _SvPainter(hue, saturation, value),
            ),
          );
        },
      ),
    );
  }
}

class _SvPainter extends CustomPainter {
  const _SvPainter(this.hue, this.s, this.v);

  final double hue, s, v;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFFFFF),
            HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF000000)],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x33000000),
    );

    final c = Offset(s * size.width, (1 - v) * size.height);
    canvas.drawCircle(
      c,
      9,
      Paint()..color = HSVColor.fromAHSV(1, hue, s, v).toColor(),
    );
    canvas.drawCircle(
      c,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      c,
      10.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66000000),
    );
  }

  @override
  bool shouldRepaint(_SvPainter old) =>
      old.hue != hue || old.s != s || old.v != v;
}

// ---------------------------------------------------------------------------
// Spectrum slider (hue / opacity)
// ---------------------------------------------------------------------------

class _TrackSlider extends StatelessWidget {
  const _TrackSlider({
    required this.label,
    required this.value,
    required this.gradient,
    required this.thumb,
    required this.onChanged,
    this.checker = false,
  });

  final String label;
  final double value;
  final Gradient gradient;
  final Color thumb;
  final bool checker;
  final ValueChanged<double> onChanged;

  static const double _inset = 10;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: label,
      value: '${(value * 100).round()}%',
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          void update(Offset p) => onChanged(
            ((p.dx - _inset) / (w - _inset * 2)).clamp(0.0, 1.0).toDouble(),
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => update(d.localPosition),
            onHorizontalDragStart: (d) => update(d.localPosition),
            onHorizontalDragUpdate: (d) => update(d.localPosition),
            child: CustomPaint(
              size: Size(w, 28),
              painter: _TrackPainter(value, gradient, thumb, checker),
            ),
          );
        },
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter(this.value, this.gradient, this.thumb, this.checker);

  final double value;
  final Gradient gradient;
  final Color thumb;
  final bool checker;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - 12;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 6, size.width, h),
      Radius.circular(h / 2),
    );
    canvas.save();
    canvas.clipRRect(track);
    if (checker) _paintChecker(canvas, track.outerRect);
    canvas.drawRect(
      track.outerRect,
      Paint()..shader = gradient.createShader(track.outerRect),
    );
    canvas.restore();
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x33000000),
    );

    final x =
        _TrackSlider._inset +
        value.clamp(0.0, 1.0).toDouble() *
            (size.width - _TrackSlider._inset * 2);
    final c = Offset(x, size.height / 2);
    canvas.drawCircle(c, 10, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(
      c,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x55000000),
    );
    canvas.drawCircle(c, 7, Paint()..color = thumb);
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.value != value ||
      old.thumb != thumb ||
      old.gradient != gradient ||
      old.checker != checker;
}

// ---------------------------------------------------------------------------
// Checkerboard (shows transparency)
// ---------------------------------------------------------------------------

void _paintChecker(Canvas canvas, Rect rect, {double cell = 6}) {
  canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFFFF));
  final dark = Paint()..color = const Color(0xFFCCCCCC);
  for (var y = 0; y * cell < rect.height; y++) {
    for (var x = 0; x * cell < rect.width; x++) {
      if ((x + y).isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + x * cell,
            rect.top + y * cell,
            cell,
            cell,
          ).intersect(rect),
          dark,
        );
      }
    }
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) =>
      _paintChecker(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(_CheckerPainter old) => false;
}
