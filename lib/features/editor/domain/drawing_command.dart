import 'stroke.dart';
import 'stroke_selection.dart';

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

/// Removes several strokes as one undoable step (one eraser drag or delete).
class RemoveStrokesCommand implements DrawingCommand {
  final List<({int index, Stroke stroke})> _entries = [];

  bool get isEmpty => _entries.isEmpty;

  /// Removes the stroke at [index] now and remembers it for undo.
  void take(List<Stroke> strokes, int index) {
    _entries.add((index: index, stroke: strokes.removeAt(index)));
  }

  @override
  void apply(List<Stroke> strokes) {
    final ids = {for (final e in _entries) e.stroke.id};
    strokes.removeWhere((s) => ids.contains(s.id));
  }

  @override
  void revert(List<Stroke> strokes) {
    for (final e in _entries.reversed) {
      final at = e.index > strokes.length ? strokes.length : e.index;
      strokes.insert(at, e.stroke);
    }
  }
}

/// Moves the strokes with the given ids by (dx, dy) in one undoable step.
class MoveStrokesCommand implements DrawingCommand {
  MoveStrokesCommand(Set<String> ids, this.dx, this.dy)
    : ids = Set<String>.unmodifiable(ids);

  final Set<String> ids;
  final double dx;
  final double dy;

  void _shift(List<Stroke> strokes, double x, double y) {
    for (var i = 0; i < strokes.length; i++) {
      if (ids.contains(strokes[i].id)) {
        strokes[i] = StrokeSelection.translate(strokes[i], x, y);
      }
    }
  }

  @override
  void apply(List<Stroke> strokes) => _shift(strokes, dx, dy);

  @override
  void revert(List<Stroke> strokes) => _shift(strokes, -dx, -dy);
}

/// Swaps strokes (matched by id) between two states in one undoable step.
/// Used for auto-recognition and for resizing.
class ReplaceStrokesCommand implements DrawingCommand {
  ReplaceStrokesCommand(List<Stroke> before, List<Stroke> after)
    : assert(before.length == after.length),
      _before = List<Stroke>.unmodifiable(before),
      _after = List<Stroke>.unmodifiable(after);

  final List<Stroke> _before;
  final List<Stroke> _after;

  void _swap(List<Stroke> strokes, List<Stroke> to) {
    final byId = {for (final s in to) s.id: s};
    for (var i = 0; i < strokes.length; i++) {
      final replacement = byId[strokes[i].id];
      if (replacement != null) strokes[i] = replacement;
    }
  }

  @override
  void apply(List<Stroke> strokes) => _swap(strokes, _after);

  @override
  void revert(List<Stroke> strokes) => _swap(strokes, _before);
}

/// Several commands as one undo step.
class CompositeCommand implements DrawingCommand {
  CompositeCommand(List<DrawingCommand> commands)
    : _commands = List<DrawingCommand>.unmodifiable(commands);

  final List<DrawingCommand> _commands;

  @override
  void apply(List<Stroke> strokes) {
    for (final c in _commands) {
      c.apply(strokes);
    }
  }

  @override
  void revert(List<Stroke> strokes) {
    for (final c in _commands.reversed) {
      c.revert(strokes);
    }
  }
}
