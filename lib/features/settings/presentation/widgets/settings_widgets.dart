import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/glass/glass_dialog.dart';
import '../../../../app/glass/glass_icon_button.dart';
import '../../../../app/glass/glass_list_tile.dart';
import '../../../../app/glass/glass_surface.dart';
import '../../../../app/glass/glass_theme.dart';
import '../../../../app/routes.dart';
import '../../../library/presentation/cover_palette.dart';

class SettingsBackButton extends StatelessWidget {
  const SettingsBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(
        child: GlassIconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.library),
        ),
      ),
    );
  }
}

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
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.glass.border),
            ),
            child: GlassSurface(
              radius: 20,
              child: Material(
                type: MaterialType.transparency,
                child: Column(children: children),
              ),
            ),
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

  Future<void> _pick(BuildContext context) async {
    final picked = await showGlassSheet<T>(
      context: context,
      builder: (sheet) => Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(title, style: Theme.of(sheet).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final o in options)
                    GlassListTile(
                      title: o.label,
                      trailing: o.value == value
                          ? Icon(
                              Icons.check,
                              color: Theme.of(sheet).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(sheet).pop(o.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = options
        .firstWhere((o) => o.value == value, orElse: () => options.first)
        .label;

    return GlassListTile(
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(current),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.outline),
        ],
      ),
      onTap: () => _pick(context),
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
    this.onCustom,
  });

  final String title;
  final List<ColorOption> options;
  final Color selected;
  final ValueChanged<Color> onChanged;
  final VoidCallback? onCustom;

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
                            color: o.color == selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: o.color == selected ? 2.5 : 1,
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
              if (onCustom != null)
                Semantics(
                  button: true,
                  label: 'Custom $title',
                  child: Tooltip(
                    message: 'Custom color',
                    child: InkResponse(
                      onTap: onCustom,
                      radius: 24,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: options.any((o) => o.color == selected)
                              ? null
                              : selected,
                          gradient: options.any((o) => o.color == selected)
                              ? const SweepGradient(
                                  colors: [
                                    Color(0xFFFF0000),
                                    Color(0xFFFFFF00),
                                    Color(0xFF00FF00),
                                    Color(0xFF00FFFF),
                                    Color(0xFF0000FF),
                                    Color(0xFFFF00FF),
                                    Color(0xFFFF0000),
                                  ],
                                )
                              : null,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 18,
                          color: Colors.white,
                        ),
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

class SettingsPercentTile extends StatelessWidget {
  const SettingsPercentTile({
    super.key,
    required this.title,
    required this.percent,
    required this.onChanged,
  });

  final String title;
  final int percent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text('$percent%'),
            ],
          ),
          Slider(
            min: 1,
            max: 100,
            divisions: 99,
            value: percent.toDouble(),
            label: '$percent%',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}
