import 'dart:io';

import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<void> shareFile(File file, String title) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: title, text: title),
    );
  }
}
