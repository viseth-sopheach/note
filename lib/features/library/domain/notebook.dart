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
  });

  final String id;
  final String title;
  final String? folderId;
  final int coverColorValue;
  final PaperTemplate template;
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
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// A separate method because `copyWith(folderId: null)` cannot tell
  /// "keep the current value" apart from "set to null (root)".
  Notebook movedTo(String? folderId, {required DateTime updatedAt}) => Notebook(
        id: id,
        title: title,
        folderId: folderId,
        coverColorValue: coverColorValue,
        template: template,
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
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        folderId,
        coverColorValue,
        template,
        createdAt,
        updatedAt,
      );
}