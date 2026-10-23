import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/glass/glass_list_tile.dart';
import '../../../sharing/application/drive_service.dart';
import '../../../sharing/application/sharing_providers.dart';
import '../widgets/settings_widgets.dart';

class IntegrationsSection extends ConsumerWidget {
  const IntegrationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DriveService.isSupported) return const SizedBox.shrink();

    return SettingsSection(
      title: 'Integrations',
      icon: Icons.link_outlined,
      children: [
        GlassListTile(
          leading: Icons.logout,
          title: 'Sign out of Google Drive',
          onTap: () async {
            await ref.read(driveServiceProvider).signOut();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Signed out of Google Drive')),
              );
          },
        ),
      ],
    );
  }
}
