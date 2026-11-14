import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/glass/glass_button.dart';
import '../../../../app/glass/glass_dialog.dart';

/// Custom color: RGB sliders, RGB number fields and Hex (3 or 6 digits),
/// always in sync. Returns an opaque ARGB int, or null if cancelled.
class RgbColorDialog extends StatefulWidget {
  const RgbColorDialog({super.key, required this.initial});

  final int initial;

  static Future<int?> show(BuildContext context, {required int initial}) =>
      showGlassDialog<int>(
        context: context,
        builder: (_) => RgbColorDialog(initial: initial),
      );

  @override
  State<RgbColorDialog> createState() => _RgbColorDialogState();
}

class _RgbColorDialogState extends State<RgbColorDialog> {
  late int _r, _g, _b;
  bool _hexOk = true;
  late final TextEditingController _hex;
  late final TextEditingController _rc, _gc, _bc;

  int get _value => 0xFF000000 | (_r << 16) | (_g << 8) | _b;

  String get _hexText =>
      (_value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  @override
  void initState() {
    super.initState();
    final c = Color(widget.initial);
    _r = (c.r * 255).round().clamp(0, 255);
    _g = (c.g * 255).round().clamp(0, 255);
    _b = (c.b * 255).round().clamp(0, 255);
    _hex = TextEditingController(text: _hexText);
    _rc = TextEditingController(text: '$_r');
    _gc = TextEditingController(text: '$_g');
    _bc = TextEditingController(text: '$_b');
  }

  @override
  void dispose() {
    _hex.dispose();
    _rc.dispose();
    _gc.dispose();
    _bc.dispose();
    super.dispose();
  }

  static void _write(TextEditingController c, String text) {
    if (c.text == text) return;
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// [source] is the field being typed in; its text is left alone.
  void _set({int? r, int? g, int? b, String? source}) {
    setState(() {
      _r = r ?? _r;
      _g = g ?? _g;
      _b = b ?? _b;
      _hexOk = true;
    });
    if (source != 'hex') _write(_hex, _hexText);
    if (source != 'r') _write(_rc, '$_r');
    if (source != 'g') _write(_gc, '$_g');
    if (source != 'b') _write(_bc, '$_b');
  }

  void _onNumber(String key, String text) {
    final v = int.tryParse(text);
    if (v == null) return;
    final clamped = v.clamp(0, 255);
    if (clamped != v) {
      _write(
        key == 'r'
            ? _rc
            : key == 'g'
            ? _gc
            : _bc,
        '$clamped',
      );
    }
    _set(
      r: key == 'r' ? clamped : null,
      g: key == 'g' ? clamped : null,
      b: key == 'b' ? clamped : null,
      source: key,
    );
  }

  void _onHex(String raw) {
    var v = raw;
    if (v.length == 3) v = v.split('').map((c) => '$c$c').join();
    final n = v.length == 6 ? int.tryParse(v, radix: 16) : null;
    if (n == null) {
      setState(() => _hexOk = false);
      return;
    }
    _set(r: (n >> 16) & 0xFF, g: (n >> 8) & 0xFF, b: n & 0xFF, source: 'hex');
  }

  void _finishEditing() {
    // Normalize every field once typing ends.
    _set();
  }

  Widget _row(
    String label,
    int value,
    Color color,
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
            activeColor: color,
            label: '$value',
            onChanged: (v) => _set(
              r: key == 'r' ? v.round() : null,
              g: key == 'g' ? v.round() : null,
              b: key == 'b' ? v.round() : null,
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
            onEditingComplete: _finishEditing,
            onTapOutside: (_) => _finishEditing(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassDialog(
      title: const Text('Custom color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Color(_value),
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
          ),
          const SizedBox(height: 12),
          _row('R', _r, Colors.red, _rc, 'r'),
          _row('G', _g, Colors.green, _gc, 'g'),
          _row('B', _b, Colors.blue, _bc, 'b'),
          const SizedBox(height: 8),
          TextField(
            controller: _hex,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
            ],
            decoration: InputDecoration(
              labelText: 'Hex',
              prefixText: '#',
              counterText: '',
              errorText: _hexOk ? null : 'Enter 3 or 6 hex digits',
            ),
            onChanged: _onHex,
            onEditingComplete: _finishEditing,
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
          onPressed: _hexOk ? () => Navigator.of(context).pop(_value) : null,
        ),
      ],
    );
  }
}
