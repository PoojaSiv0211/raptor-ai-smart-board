import 'package:flutter/material.dart';
import '../drawing_controller.dart';
import '../models/stroke_model.dart';
import 'drawing_tool.dart';

class PenTool extends DrawingTool {
  PenTool(this.controller);

  final DrawingController controller;
  final List<Offset> _pts = [];

  @override
  void onStart(Offset point) {
    _pts
      ..clear()
      ..add(point);
    controller.setPreview(
      StrokeAction(
        StrokeModel(
          kind: StrokeKind.pen,
          points: List.of(_pts),
          color: controller.color,
          strokeWidth: controller.strokeWidth,
          opacity: 1.0,
        ),
      ),
    );
  }

  @override
  void onUpdate(Offset point) {
    _pts.add(point);
    controller.setPreview(
      StrokeAction(
        StrokeModel(
          kind: StrokeKind.pen,
          points: List.of(_pts),
          color: controller.color,
          strokeWidth: controller.strokeWidth,
          opacity: 1.0,
        ),
      ),
    );
  }

  @override
  void onEnd() {
    if (_pts.length < 2) {
      controller.setPreview(null);
      return;
    }
    controller.commitAction(
      StrokeAction(
        StrokeModel(
          kind: StrokeKind.pen,
          points: List.of(_pts),
          color: controller.color,
          strokeWidth: controller.strokeWidth,
          opacity: 1.0,
        ),
      ),
    );
  }

  @override
  void paint(Canvas canvas) {}
}
