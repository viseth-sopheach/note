import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/glass/glass_divider.dart';
import '../../../../app/glass/glass_list_tile.dart';
import '../../application/settings_providers.dart';
import '../widgets/settings_widgets.dart';

class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider);
    final name = info.value?.appName ?? 'VisethNote';

    final version = info.when(
      data: (i) => '${i.version} (${i.buildNumber})',
      loading: () => 'Loading…',
      error: (error, stack) => 'Unavailable',
    );

    return SettingsSection(
      title: 'About',
      icon: Icons.info_outline,
      children: [
        GlassListTile(title: 'App', trailing: Text(name)),
        const GlassDivider(),
        GlassListTile(title: 'Version', trailing: Text(version)),
      ],
    );
  }
}
