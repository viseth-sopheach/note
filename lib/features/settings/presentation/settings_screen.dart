import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settings_providers.dart';
import '../domain/app_theme_mode.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static IconData _iconFor(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => Icons.brightness_auto_outlined,
        AppThemeMode.light => Icons.light_mode_outlined,
        AppThemeMode.dark => Icons.dark_mode_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<AppThemeMode>(
              showSelectedIcon: false,
              segments: [
                for (final m in AppThemeMode.values)
                  ButtonSegment(
                    value: m,
                    icon: Icon(_iconFor(m)),
                    label: Text(m.label),
                  ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => ref
                  .read(appThemeModeProvider.notifier)
                  .setMode(selection.first),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Notebook paper stays white in every theme.',
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          Text('About', style: textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'VisethNote',
            ),
          ),
        ],
      ),
    );
  }
}