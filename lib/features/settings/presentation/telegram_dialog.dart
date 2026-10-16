import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sharing/application/sharing_providers.dart';

class TelegramDialog extends ConsumerStatefulWidget {
  const TelegramDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const TelegramDialog());

  @override
  ConsumerState<TelegramDialog> createState() => _TelegramDialogState();
}

class _TelegramDialogState extends ConsumerState<TelegramDialog> {
  final _token = TextEditingController();
  final _chat = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(telegramServiceProvider).loadConfig().then((config) {
      if (config == null || !mounted) return;
      _token.text = config.botToken;
      _chat.text = config.chatId;
    });
  }

  @override
  void dispose() {
    _token.dispose();
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(telegramServiceProvider);
    return AlertDialog(
      title: const Text('Telegram'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _token,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Bot token'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _chat,
            decoration: const InputDecoration(labelText: 'Chat ID'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await service.clearConfig();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Remove'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await service.saveConfig(_token.text, _chat.text);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}