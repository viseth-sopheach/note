import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../app/router.dart';
import '../../../app/routes.dart';
import '../application/sharing_providers.dart';

/// Opens PDFs shared from Drive, Telegram, Files and other apps as a new notebook.
class ShareIntentListener extends ConsumerStatefulWidget {
  const ShareIntentListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareIntentListener> createState() =>
      _ShareIntentListenerState();
}

class _ShareIntentListenerState extends ConsumerState<ShareIntentListener> {
  StreamSubscription<List<SharedMediaFile>>? _sub;
  final Set<String> _handled = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    // App was closed: wait for the first frame so the router is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final initial = await ReceiveSharingIntent.instance.getInitialMedia();
        await _handle(initial);
      } catch (_) {}
    });

    // App was already running.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handle,
      onError: (_) {},
    );
  }

  Future<void> _handle(List<SharedMediaFile> files) async {
    if (files.isEmpty || _busy) return;
    _busy = true;
    try {
      for (final file in files) {
        final path = file.path;
        if (!path.toLowerCase().endsWith('.pdf')) continue;
        if (!_handled.add(path)) continue;

        try {
          final notebook = await ref
              .read(importServiceProvider)
              .importPdf(path);
          if (notebook != null) {
            appRouter.push(AppRoutes.notebook(notebook.id));
          } else {
            _toast('Could not read the PDF.');
          }
        } catch (_) {
          _toast('Could not import the PDF.');
        }
      }
    } finally {
      ReceiveSharingIntent.instance.reset();
      _busy = false;
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
