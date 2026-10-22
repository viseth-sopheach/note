import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../application/settings_providers.dart';
import '../../domain/app_settings.dart';
import '../widgets/settings_widgets.dart';

class EditorSection extends ConsumerWidget {
  const EditorSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return SettingsSection(
      title: 'Editor & Toolbar',
      icon: Icons.draw_outlined,
      children: [
        SettingsChoiceTile<double>(
          title: 'Default zoom',
          subtitle: 'Narrow screens still fit the page width',
          value: settings.defaultZoom,
          options: [
            for (final z in AppSettings.zoomLevels)
              (value: z, label: '${(z * 100).round()}%'),
          ],
          onChanged: (z) => notifier.update((s) => s.copyWith(defaultZoom: z)),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Ctrl + mouse wheel zooms'),
          subtitle: const Text('Off: the wheel only scrolls'),
          value: settings.wheelZoom,
          onChanged: (v) => notifier.update((s) => s.copyWith(wheelZoom: v)),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.view_list_outlined),
          title: const Text('Customize toolbar'),
          subtitle: const Text('Order and visibility of tools'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.settingsToolbar),
        ),
        const Divider(height: 1),
        SettingsChoiceTile<int>(
          title: 'Undo history',
          subtitle: 'Applies to notebooks opened afterwards',
          value: settings.undoLimit,
          options: [
            for (final n in AppSettings.undoLimits)
              (value: n, label: '$n steps'),
          ],
          onChanged: (n) => notifier.update((s) => s.copyWith(undoLimit: n)),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Confirm before deleting a page'),
          value: settings.confirmDeletePage,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(confirmDeletePage: v)),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Remember last position'),
          subtitle: const Text('Reopen notebooks where you left off'),
          value: settings.rememberPosition,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(rememberPosition: v)),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Shape recognition'),
          subtitle: const Text(
            'Hold at the end of a stroke to snap it to a clean shape',
          ),
          value: settings.shapeRecognition,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(shapeRecognition: v)),
        ),
      ],
    );
  }
}
