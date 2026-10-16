import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings_providers.dart';
import '../../domain/app_theme_mode.dart';
import '../../domain/layout_density.dart';
import '../widgets/settings_widgets.dart';

const List<ColorOption> kAccentColors = [
  ColorOption('Blue grey', Color(0xFF607D8B)),
  ColorOption('Slate blue', Color(0xFF3F5F8A)),
  ColorOption('Sage green', Color(0xFF4F7F6A)),
  ColorOption('Brick', Color(0xFF8A4F4F)),
  ColorOption('Muted purple', Color(0xFF7A5C99)),
  ColorOption('Amber', Color(0xFFB07D3A)),
  ColorOption('Charcoal', Color(0xFF3A3A3A)),
];

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  static IconData _iconFor(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => Icons.brightness_auto_outlined,
    AppThemeMode.light => Icons.light_mode_outlined,
    AppThemeMode.dark => Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.outline;

    return SettingsSection(
      title: 'Appearance',
      icon: Icons.palette_outlined,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theme', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              SegmentedButton<AppThemeMode>(
                showSelectedIcon: false,
                segments: [
                  for (final m in AppThemeMode.values)
                    ButtonSegment(
                      value: m,
                      icon: Icon(_iconFor(m)),
                      label: Text(m.label),
                    ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => notifier.setMode(s.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Notebook paper stays white in every theme.',
                style: textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SettingsColorRow(
          title: 'Accent color',
          options: kAccentColors,
          selected: Color(settings.accentColorValue),
          onChanged: (c) => notifier.update(
            (s) => s.copyWith(accentColorValue: c.toARGB32()),
          ),
        ),
        const Divider(height: 1),
        SettingsChoiceTile<LayoutDensity>(
          title: 'Layout density',
          subtitle: 'Spacing of lists, buttons and the library',
          value: settings.density,
          options: [
            for (final d in LayoutDensity.values) (value: d, label: d.label),
          ],
          onChanged: (d) => notifier.update((s) => s.copyWith(density: d)),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Show notebook covers'),
          subtitle: const Text('Off shows plain tiles in the library'),
          value: settings.showCovers,
          onChanged: (v) => notifier.update((s) => s.copyWith(showCovers: v)),
        ),
      ],
    );
  }
}
