import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

class DriveService {
	static bool get isSupported =>
		Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

	final GoogleSignIn _signIn = GoogleSignIn.instance;
	bool _initialized = false;

	Future<void> _initialize() async {
		if (_initialized) return;

		await _signIn.initialize();
		_initialized = true;
	}

	Future<void> upload(File file) async {
		await _initialize();

		final account = await _signIn.authenticate(
			scopeHint: [drive.DriveApi.driveFileScope],
		);

		final authorization = await account.authorizationClient
			.authorizationForScopes([drive.DriveApi.driveFileScope]);

		if (authorization == null) {
			throw StateError('Google Drive authorization failed.');
		}

		final client = authorization.authClient(scopes: [
			drive.DriveApi.driveFileScope,
		]);

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

	Future<void> signOut() async {
		await _initialize();
		await _signIn.signOut();
	}
}
