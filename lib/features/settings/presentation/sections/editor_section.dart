import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/glass/glass_divider.dart';
import '../../../../app/glass/glass_list_tile.dart';
import '../../../../app/glass/glass_switch_tile.dart';
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
        const GlassDivider(),
        GlassSwitchTile(
          title: 'Ctrl + mouse wheel zooms',
          subtitle: 'Off: the wheel only scrolls',
          value: settings.wheelZoom,
          onChanged: (v) => notifier.update((s) => s.copyWith(wheelZoom: v)),
        ),
        const GlassDivider(),
        GlassListTile(
          leading: Icons.view_list_outlined,
          title: 'Customize toolbar',
          subtitle: 'Order and visibility of tools',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.settingsToolbar),
        ),
        const GlassDivider(),
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
        const GlassDivider(),
        GlassSwitchTile(
          title: 'Confirm before deleting a page',
          value: settings.confirmDeletePage,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(confirmDeletePage: v)),
        ),
        const GlassDivider(),
        GlassSwitchTile(
          title: 'Remember last position',
          subtitle: 'Reopen notebooks where you left off',
          value: settings.rememberPosition,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(rememberPosition: v)),
        ),
        const GlassDivider(),
        GlassSwitchTile(
          title: 'Shape recognition',
          subtitle: 'Hold at the end of a stroke to snap it to a clean shape',
          value: settings.shapeRecognition,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(shapeRecognition: v)),
        ),
      ],
    );
  }
}
