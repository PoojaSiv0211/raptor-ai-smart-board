import 'package:flutter/material.dart';
import '../drawing_controller.dart';
import '../models/table_model.dart';
import 'drawing_tool.dart';

class TableTool extends DrawingTool {
  TableTool(this.controller);

  final DrawingController controller;

  // You can expose these as UI controls later.
  int rows = 4;
  int cols = 4;
  double cellWidth = 90;
  double cellHeight = 60;

  Offset? _origin;
  Offset? _current;

  @override
  void onStart(Offset point) {
    _origin = point;
    _current = point;
    controller.setPreview(_preview());
  }

  @override
  void onUpdate(Offset point) {
    _current = point;

    // Smart behavior: drag changes rows/cols based on drag distance
    final dx = (_current!.dx - _origin!.dx).abs();
    final dy = (_current!.dy - _origin!.dy).abs();
    cols = (dx / cellWidth).clamp(1, 12).round();
    rows = (dy / cellHeight).clamp(1, 12).round();

    controller.setPreview(_preview());
  }

  @override
  void onEnd() {
    if (_origin == null) {
      controller.setPreview(null);
      return;
    }
    controller.commitAction(
      TableAction(
        TableModel(
          origin: _origin!,
          rows: rows,
          cols: cols,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
          color: controller.color,
          strokeWidth: controller.strokeWidth,
        ),
      ),
    );
    _origin = null;
    _current = null;
  }

  TableAction _preview() {
    return TableAction(
      TableModel(
        origin: _origin!,
        rows: rows,
        cols: cols,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        color: controller.color.withOpacity(0.95),
        strokeWidth: controller.strokeWidth,
      ),
    );
  }

  @override
  void paint(Canvas canvas) {}
}
