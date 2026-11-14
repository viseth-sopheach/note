import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/glass/glass_button.dart';
import '../../../../app/glass/glass_dialog.dart';

/// Full 0-255 RGB picker. Returns an opaque ARGB int, or null if cancelled.
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
  late final TextEditingController _hex;

  int get _value => 0xFF000000 | (_r << 16) | (_g << 8) | _b;

  String get _hexText => (_value & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();

  @override
  void initState() {
    super.initState();
    final c = Color(widget.initial);
    _r = (c.r * 255).round().clamp(0, 255);
    _g = (c.g * 255).round().clamp(0, 255);
    _b = (c.b * 255).round().clamp(0, 255);
    _hex = TextEditingController(text: _hexText);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set({int? r, int? g, int? b}) {
    setState(() {
      _r = r ?? _r;
      _g = g ?? _g;
      _b = b ?? _b;
      _hex.text = _hexText;
    });
  }

  void _onHex(String v) {
    if (v.length != 6) return;
    final n = int.tryParse(v, radix: 16);
    if (n == null) return;
    setState(() {
      _r = (n >> 16) & 0xFF;
      _g = (n >> 8) & 0xFF;
      _b = n & 0xFF;
    });
  }

  Widget _slider(String label, int value, Color color, ValueChanged<int> on) {
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
            onChanged: (v) => on(v.round()),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text('$value', textAlign: TextAlign.end),
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
          _slider('R', _r, Colors.red, (v) => _set(r: v)),
          _slider('G', _g, Colors.green, (v) => _set(g: v)),
          _slider('B', _b, Colors.blue, (v) => _set(b: v)),
          TextField(
            controller: _hex,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Hex',
              prefixText: '#',
              counterText: '',
            ),
            onChanged: _onHex,
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
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}