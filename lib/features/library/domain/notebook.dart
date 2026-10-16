import 'paper_template.dart';

final class Notebook {
  const Notebook({
    required this.id,
    required this.title,
    required this.coverColorValue,
    required this.template,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.pdfPath,
  });

  final String id;
  final String title;
  final String? folderId;
  final int coverColorValue;
  final PaperTemplate template;

  /// Absolute path of the imported PDF, or null for a normal notebook.
  final String? pdfPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Notebook copyWith({
    String? title,
    int? coverColorValue,
    PaperTemplate? template,
    required DateTime updatedAt,
  }) =>
      Notebook(
        id: id,
        title: title ?? this.title,
        folderId: folderId,
        coverColorValue: coverColorValue ?? this.coverColorValue,
        template: template ?? this.template,
        pdfPath: pdfPath,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Notebook movedTo(String? folderId, {required DateTime updatedAt}) => Notebook(
        id: id,
        title: title,
        folderId: folderId,
        coverColorValue: coverColorValue,
        template: template,
        pdfPath: pdfPath,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Notebook &&
      other.id == id &&
      other.title == title &&
      other.folderId == folderId &&
      other.coverColorValue == coverColorValue &&
      other.template == template &&
      other.pdfPath == pdfPath &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        folderId,
        coverColorValue,
        template,
        pdfPath,
        createdAt,
        updatedAt,
      );
}