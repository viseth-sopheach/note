import 'drawing_command.dart';
import 'stroke.dart';

/// Undo and redo stacks. Committing a new command clears the redo stack.
final class CommandHistory {
  CommandHistory({this.limit = 200});

  /// Oldest commands are dropped beyond this many.
  final int limit;

  final List<DrawingCommand> _undo = [];
  final List<DrawingCommand> _redo = [];

  bool get canUndo => _undo.isNotEmpty;

  bool get canRedo => _redo.isNotEmpty;

  void execute(DrawingCommand command, List<Stroke> strokes) {
    command.apply(strokes);
    record(command);
  }

  /// Adds a command whose effect was already applied.
  void record(DrawingCommand command) {
    _undo.add(command);
    _redo.clear();
    if (_undo.length > limit) _undo.removeAt(0);
  }

  /// Returns true when something was undone.
  bool undo(List<Stroke> strokes) {
    if (_undo.isEmpty) return false;
    final command = _undo.removeLast();
    command.revert(strokes);
    _redo.add(command);
    return true;
  }

  /// Returns true when something was redone.
  bool redo(List<Stroke> strokes) {
    if (_redo.isEmpty) return false;
    final command = _redo.removeLast();
    command.apply(strokes);
    _undo.add(command);
    return true;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
