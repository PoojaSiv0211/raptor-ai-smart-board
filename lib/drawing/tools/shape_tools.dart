import 'package:flutter/material.dart';
import '../drawing_controller.dart';
import '../models/shape_model.dart';
import 'drawing_tool.dart';

class ShapeTool extends DrawingTool {
  ShapeTool(this.controller);

  final DrawingController controller;
  Offset? _start;
  Offset? _end;

  @override
  void onStart(Offset point) {
    _start = point;
    _end = point;
    controller.setPreview(_makePreview());
  }

  @override
  void onUpdate(Offset point) {
    _end = point;
    controller.setPreview(_makePreview());
  }

  @override
  void onEnd() {
    final s = _start;
    final e = _end;
    if (s == null || e == null) {
      controller.setPreview(null);
      return;
    }

    controller.commitAction(
      ShapeAction(
        ShapeModel(
          type: controller.activeShapeType,
          start: s,
          end: e,
          color: controller.color,
          strokeWidth: controller.strokeWidth,
        ),
      ),
    );

    _start = null;
    _end = null;
  }

  ShapeAction _makePreview() {
    return ShapeAction(
      ShapeModel(
        type: controller.activeShapeType,
        start: _start!,
        end: _end!,
        color: controller.color.withOpacity(0.95),
        strokeWidth: controller.strokeWidth,
      ),
    );
  }

  @override
  void paint(Canvas canvas) {}
}

/// Pure painter helpers, used by ShapeAction
class ShapePainter {
  static void drawShape(Canvas canvas, Paint paint, ShapeModel shape) {
    final rect = shape.rect;
    switch (shape.type) {
      case ShapeType.rectangle:
        canvas.drawRect(rect, paint);
        break;

      case ShapeType.roundedRect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(shape.cornerRadius)),
          paint,
        );
        break;

      case ShapeType.circle:
        {
          final center = rect.center;
          final r = (rect.shortestSide / 2).abs();
          canvas.drawCircle(center, r, paint);
          break;
        }

      case ShapeType.ellipse:
        canvas.drawOval(rect, paint);
        break;

      case ShapeType.triangle:
        {
          final p = Path()
            ..moveTo(rect.center.dx, rect.top)
            ..lineTo(rect.right, rect.bottom)
            ..lineTo(rect.left, rect.bottom)
            ..close();
          canvas.drawPath(p, paint);
          break;
        }

      case ShapeType.diamond:
        {
          final p = Path()
            ..moveTo(rect.center.dx, rect.top)
            ..lineTo(rect.right, rect.center.dy)
            ..lineTo(rect.center.dx, rect.bottom)
            ..lineTo(rect.left, rect.center.dy)
            ..close();
          canvas.drawPath(p, paint);
          break;
        }

      case ShapeType.line:
        canvas.drawLine(shape.start, shape.end, paint);
        break;

      case ShapeType.arrow:
        {
          // line + arrow head
          canvas.drawLine(shape.start, shape.end, paint);
          final head = _arrowHead(shape.start, shape.end, 14);
          canvas.drawPath(head, paint);
          break;
        }
    }
  }

  static Path _arrowHead(Offset a, Offset b, double size) {
    final v = (a - b);
    final len = v.distance == 0 ? 1.0 : v.distance;
    final ux = v.dx / len;
    final uy = v.dy / len;

    final left = Offset(
      b.dx + (ux * size) - (uy * size * 0.6),
      b.dy + (uy * size) + (ux * size * 0.6),
    );
    final right = Offset(
      b.dx + (ux * size) + (uy * size * 0.6),
      b.dy + (uy * size) - (ux * size * 0.6),
    );

    return Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo(left.dx, left.dy)
      ..moveTo(b.dx, b.dy)
      ..lineTo(right.dx, right.dy);
  }
}
