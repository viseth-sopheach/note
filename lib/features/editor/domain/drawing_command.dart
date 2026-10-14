import 'stroke.dart';

/// One undoable change to the strokes of a page. No Flutter imports.
abstract interface class DrawingCommand {
  void apply(List<Stroke> strokes);

  void revert(List<Stroke> strokes);
}

class AddStrokeCommand implements DrawingCommand {
  AddStrokeCommand(this.stroke);

  final Stroke stroke;

  @override
  void apply(List<Stroke> strokes) => strokes.add(stroke);

  @override
  void revert(List<Stroke> strokes) =>
      strokes.removeWhere((s) => s.id == stroke.id);
}