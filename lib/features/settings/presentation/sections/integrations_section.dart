import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sharing/application/drive_service.dart';
import '../../../sharing/application/sharing_providers.dart';
import '../telegram_dialog.dart';
import '../widgets/settings_widgets.dart';

class IntegrationsSection extends ConsumerWidget {
  const IntegrationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: 'Integrations',
      icon: Icons.link_outlined,
      children: [
        ListTile(
          leading: const Icon(Icons.send_outlined),
          title: const Text('Telegram bot'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => TelegramDialog.show(context),
        ),
        if (DriveService.isSupported) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out of Google Drive'),
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
      ],
    );
  }
}
