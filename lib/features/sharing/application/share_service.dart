import 'dart:io';

import 'package:share_plus/share_plus.dart';

class ShareService {
  /// Shares only the file as an attachment, with no subject or text.
  Future<void> shareFile(File file, String title) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
    );
  }
}