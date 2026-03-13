import 'dart:collection';

abstract class CanvasCommand {
  void execute();
  void undo();
}

/// Command stack with undo/redo and limit.
class CommandStack {
  CommandStack({this.limit = 50});

  final int limit;
  final ListQueue<CanvasCommand> _undo = ListQueue();
  final ListQueue<CanvasCommand> _redo = ListQueue();

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void run(CanvasCommand cmd) {
    cmd.execute();
    _undo.addLast(cmd);
    _redo.clear();

    while (_undo.length > limit) {
      _undo.removeFirst();
    }
  }

  void undo() {
    if (_undo.isEmpty) return;
    final cmd = _undo.removeLast();
    cmd.undo();
    _redo.addLast(cmd);

    while (_redo.length > limit) {
      _redo.removeFirst();
    }
  }

  void redo() {
    if (_redo.isEmpty) return;
    final cmd = _redo.removeLast();
    cmd.execute();
    _undo.addLast(cmd);

    while (_undo.length > limit) {
      _undo.removeFirst();
    }
  }

  void clearHistory() {
    _undo.clear();
    _redo.clear();
  }
}
