import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        ListTile(title: const Text('App'), trailing: Text(name)),
        const Divider(height: 1),
        ListTile(title: const Text('Version'), trailing: Text(version)),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Open-source licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: name,
            applicationVersion: info.value?.version,
          ),
        ),
      ],
    );
  }
}
