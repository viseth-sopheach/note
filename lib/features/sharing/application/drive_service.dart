import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

class DriveService {
  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  Future<void> upload(File file) async {
    final account = await _signIn.signInSilently() ?? await _signIn.signIn();
    if (account == null) throw StateError('Google sign-in was cancelled.');

    final client = await _signIn.authenticatedClient();
    if (client == null) throw StateError('Google authorization failed.');
    try {
      final api = drive.DriveApi(client);
      final media = drive.Media(file.openRead(), await file.length());
      await api.files.create(
        drive.File()..name = p.basename(file.path),
        uploadMedia: media,
      );
    } finally {
      client.close();
    }
  }

  Future<void> signOut() => _signIn.signOut();
}
