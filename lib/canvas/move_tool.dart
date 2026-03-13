import 'package:flutter/material.dart';
import 'command_system.dart';
import 'canvas_manager.dart';
import 'drawables.dart';

class MoveToolController {
  MoveToolController(this.vm);

  final CanvasManager vm;

  String? _activeId;
  Offset _last = Offset.zero;

  DrawableItem? _beforeSnapshot;

  void onStart(Offset p) {
    final hit = vm.hitTest(p);
    if (hit == null) {
      vm.selectedId = null;
      return;
    }

    vm.selectedId = hit.id;
    _activeId = hit.id;
    _last = p;
    _beforeSnapshot = hit; // capture original
  }

  void onUpdate(Offset p) {
    if (_activeId == null) return;

    final delta = p - _last;
    _last = p;

    final id = _activeId!;
    final item = vm.getById(id);
    if (item == null) return;

    // live drag (no history spam)
    vm.replaceItemInternal(id, item.translated(delta));
  }

  void onEnd() {
    final id = _activeId;
    final before = _beforeSnapshot;
    if (id == null || before == null) {
      _reset();
      return;
    }

    final after = vm.getById(id);
    if (after == null) {
      _reset();
      return;
    }

    // Push ONE command for the entire drag
    vm.run(_MoveFinalCommand(vm, id: id, before: before, after: after));

    _reset();
  }

  void _reset() {
    _activeId = null;
    _beforeSnapshot = null;
  }
}

class _MoveFinalCommand implements CanvasCommand {
  _MoveFinalCommand(
    this.vm, {
    required this.id,
    required this.before,
    required this.after,
  });

  final CanvasManager vm;
  final String id;
  final DrawableItem before;
  final DrawableItem after;

  @override
  void execute() => vm.replaceItemInternal(id, after);

  @override
  void undo() => vm.replaceItemInternal(id, before);
}
