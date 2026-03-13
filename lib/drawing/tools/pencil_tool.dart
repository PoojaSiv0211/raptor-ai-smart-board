import 'package:flutter/material.dart';
import '../drawing_controller.dart';
import '../models/stroke_model.dart';
import 'drawing_tool.dart';

class PencilTool extends DrawingTool {
  PencilTool(this.controller);

  final DrawingController controller;
  final List<Offset> _pts = [];

  @override
  void onStart(Offset point) {
    _pts
      ..clear()
      ..add(point);

    controller.setPreview(_makeAction());
  }

  @override
  void onUpdate(Offset point) {
    _pts.add(point);
    controller.setPreview(_makeAction());
  }

  StrokeAction _makeAction() {
    return StrokeAction(
      StrokeModel(
        kind: StrokeKind.pencil,
        points: List.of(_pts),
        color: controller.color,
        strokeWidth: (controller.strokeWidth * 0.75).clamp(1, 18),
        opacity: 0.75,
      ),
    );
  }

  @override
  void onEnd() {
    if (_pts.length < 2) {
      controller.setPreview(null);
      return;
    }
    controller.commitAction(_makeAction());
  }

  @override
  void paint(Canvas canvas) {}
}
