import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../editor/application/editor_providers.dart';
import '../../library/application/library_actions.dart';
import '../../library/domain/name_rules.dart';
import '../../library/domain/notebook.dart';
import '../../library/domain/paper_template.dart';
import '../../library/presentation/cover_palette.dart';

class ImportService {
  ImportService(this._ref);

  final Ref _ref;

  static const int maxPdfBytes = 500 << 20;

  /// Throws when the file is missing, empty, too large or not a PDF.
  Future<({String name, int bytes})> inspectPdf(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const FileSystemException('File not found');
    final bytes = await file.length();
    if (bytes == 0 || bytes > maxPdfBytes) {
      throw const FormatException('Unsupported file size');
    }
    final raf = await file.open();
    try {
      final head = await raf.read(1024);
      const magic = [0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-
      var found = false;
      for (var i = 0; i + magic.length <= head.length && !found; i++) {
        found = true;
        for (var j = 0; j < magic.length; j++) {
          if (head[i + j] != magic[j]) {
            found = false;
            break;
          }
        }
      }
      if (!found) throw const FormatException('Not a PDF');
    } finally {
      await raf.close();
    }
    return (name: p.basename(path), bytes: bytes);
  }

  /// Deletes temporary copies made by the share intent / extension.
  Future<void> discardSources(List<String> paths) async {
    final tmp = (await getTemporaryDirectory()).path;
    for (final path in paths) {
      final temp = p.isWithin(tmp, path);
      final group = path.contains('/Shared/AppGroup/');
      if (!temp && !group) continue;
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

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
    if (title.length > kMaxNameLength) {
      title = title.substring(0, kMaxNameLength);
    }

    try {
      return await _ref
          .read(libraryActionsProvider)
          .createNotebook(
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

  /// Copies an image into app storage. Returns the new path, or null.
  Future<String?> storeImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'images'));
    await dir.create(recursive: true);
    final ext = p.extension(sourcePath).toLowerCase();
    final target = File(
      p.join(dir.path, '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}'),
    );
    await source.copy(target.path);
    return target.path;
  }

  /// Creates a notebook with one page per image.
  Future<Notebook?> importImages(
    List<String> sourcePaths, {
    String? folderId,
  }) async {
    final stored = <String>[];
    for (final s in sourcePaths) {
      final t = await storeImage(s);
      if (t != null) stored.add(t);
    }
    if (stored.isEmpty) return null;

    var title = p.basenameWithoutExtension(sourcePaths.first).trim();
    if (title.isEmpty) title = 'Imported images';
    if (title.length > kMaxNameLength) {
      title = title.substring(0, kMaxNameLength);
    }

    Notebook? notebook;
    try {
      notebook = await _ref
          .read(libraryActionsProvider)
          .createNotebook(
            title: title,
            coverColorValue: CoverPalette.colors.first.toARGB32(),
            template: PaperTemplate.blank,
            folderId: folderId,
          );
      final pages = _ref.read(pageRepositoryProvider);
      for (var i = 0; i < stored.length; i++) {
        await pages.insertPage(
          notebook.id,
          pageIndex: i,
          template: PaperTemplate.blank,
          imagePath: stored[i],
        );
      }
      return notebook;
    } catch (_) {
      for (final t in stored) {
        try {
          await File(t).delete();
        } catch (_) {}
      }
      if (notebook != null) {
        await _ref.read(libraryActionsProvider).deleteNotebook(notebook.id);
      }
      rethrow;
    }
  }
}
