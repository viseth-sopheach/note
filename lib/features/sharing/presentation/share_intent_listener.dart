import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../app/router.dart';
import '../../../app/routes.dart';
import '../application/sharing_providers.dart';

/// Opens PDFs shared from Drive, Telegram and other apps as a new notebook.
class ShareIntentListener extends ConsumerStatefulWidget {
  const ShareIntentListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareIntentListener> createState() =>
      _ShareIntentListenerState();
}

class _ShareIntentListenerState extends ConsumerState<ShareIntentListener> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    ReceiveSharingIntent.instance.getInitialMedia().then(_handle);
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_handle);
  }

  Future<void> _handle(List<SharedMediaFile> files) async {
    for (final file in files) {
      if (!file.path.toLowerCase().endsWith('.pdf')) continue;
      final notebook =
          await ref.read(importServiceProvider).importPdf(file.path);
      if (notebook != null) {
        appRouter.push(AppRoutes.notebook(notebook.id));
      }
    }
    ReceiveSharingIntent.instance.reset();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}