import '../../library/domain/paper_template.dart';

enum ExportPaper {
  original('Original'),
  blank('Blank'),
  lined('Lined'),
  dotted('Dotted'),
  grid('Grid');

  const ExportPaper(this.label);
  final String label;

  /// Null keeps each page's own template.
  PaperTemplate? get template => switch (this) {
    ExportPaper.original => null,
    ExportPaper.blank => PaperTemplate.blank,
    ExportPaper.lined => PaperTemplate.lined,
    ExportPaper.dotted => PaperTemplate.dotted,
    ExportPaper.grid => PaperTemplate.grid,
  };
}

enum ExportColorMode { light, dark }

final class ExportOptions {
  const ExportOptions({
    this.paper = ExportPaper.original,
    this.colorMode = ExportColorMode.light,
  });

  final ExportPaper paper;
  final ExportColorMode colorMode;

  ExportOptions copyWith({ExportPaper? paper, ExportColorMode? colorMode}) =>
      ExportOptions(
        paper: paper ?? this.paper,
        colorMode: colorMode ?? this.colorMode,
      );
}