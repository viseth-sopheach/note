import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../library/application/library_actions.dart';
import '../../library/domain/name_rules.dart';
import '../../library/domain/notebook.dart';
import '../../library/domain/paper_template.dart';
import '../../library/presentation/cover_palette.dart';

class ImportService {
  ImportService(this._ref);

  final Ref _ref;

  Future<Notebook?> importPdf(String sourcePath, {String? folderId}) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'pdfs'));
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, '${const Uuid().v4()}.pdf'));
    await source.copy(target.path);

    var title = p.basenameWithoutExtension(sourcePath).trim();
    if (title.isEmpty) title = 'Imported PDF';
    if (title.length > kMaxNameLength) title = title.substring(0, kMaxNameLength);

    try {
      return await _ref.read(libraryActionsProvider).createNotebook(
            title: title,
            coverColorValue: CoverPalette.colors.first.toARGB32(),
            template: PaperTemplate.blank,
            folderId: folderId,
            pdfPath: target.path,
          );
    } catch (_) {
      await target.delete();
      rethrow;
    }
  }
}