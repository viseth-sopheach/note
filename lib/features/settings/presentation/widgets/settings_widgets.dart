import 'package:flutter/material.dart';

import '../../../../library/presentation/cover_palette.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Card.outlined(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class SettingsChoiceTile<T> extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final T value;
  final List<({T value, String label})> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        items: [
          for (final o in options)
            DropdownMenuItem<T>(value: o.value, child: Text(o.label)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class ColorOption {
  const ColorOption(this.name, this.color);

  final String name;
  final Color color;
}

class SettingsColorRow extends StatelessWidget {
  const SettingsColorRow({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<ColorOption> options;
  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final o in options)
                Semantics(
                  button: true,
                  selected: o.color == selected,
                  label: '${o.name} $title',
                  child: Tooltip(
                    message: o.name,
                    child: InkResponse(
                      onTap: () => onChanged(o.color),
                      radius: 24,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: o.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: o.color == selected
                            ? Icon(
                                Icons.check,
                                size: 20,
                                color: CoverPalette.onColor(o.color),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
