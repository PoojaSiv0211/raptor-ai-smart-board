import 'package:flutter/material.dart';
import '../drawing_controller.dart';
import '../models/stroke_model.dart';
import 'drawing_tool.dart';

class EraserTool extends DrawingTool {
  EraserTool(this.controller);

  final DrawingController controller;
  final List<Offset> _pts = [];

  @override
  void onStart(Offset point) {
    _pts
      ..clear()
      ..add(point);
    controller.setPreview(_make());
  }

  @override
  void onUpdate(Offset point) {
    _pts.add(point);
    controller.setPreview(_make());
  }

  StrokeAction _make() {
    return StrokeAction(
      StrokeModel(
        kind: StrokeKind.eraser,
        points: List.of(_pts),
        color: Colors.transparent,
        strokeWidth: (controller.strokeWidth * 2.2).clamp(6, 64),
        opacity: 1.0,
      ),
    );
  }

  @override
  void onEnd() {
    if (_pts.length < 2) {
      controller.setPreview(null);
      return;
    }
    controller.commitAction(_make());
  }

  @override
  void paint(Canvas canvas) {}
}
