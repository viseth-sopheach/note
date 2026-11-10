import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static bool get _desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Mobile: opens the share sheet.
  /// Desktop: saves to Downloads and reveals the file.
  Future<void> shareFile(File file, String title) async {
    if (!_desktop) {
      final view = PlatformDispatcher.instance.views.first;
      final size = view.physicalSize / view.devicePixelRatio;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          sharePositionOrigin: Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: 1,
            height: 1,
          ),
        ),
      );
      return;
    }

    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    var target = File(p.join(dir.path, p.basename(file.path)));
    var n = 1;
    while (await target.exists()) {
      final name = p.basenameWithoutExtension(file.path);
      target = File(p.join(dir.path, '$name ($n).pdf'));
      n++;
    }
    await file.copy(target.path);

    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', target.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', target.path]);
    } else {
      await Process.run('xdg-open', [dir.path]);
    }
  }
}
