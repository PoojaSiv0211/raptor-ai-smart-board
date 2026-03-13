import 'dart:ui';

enum ShapeType {
  rectangle,
  roundedRect,
  circle,
  ellipse,
  triangle,
  diamond,
  line,
  arrow,
}

class ShapeModel {
  ShapeModel({
    required this.type,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
    this.cornerRadius = 16,
  });

  final ShapeType type;
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;
  final double cornerRadius;

  Rect get rect => Rect.fromPoints(start, end);
}