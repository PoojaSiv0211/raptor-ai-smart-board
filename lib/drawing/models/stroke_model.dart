import 'dart:ui';

enum StrokeKind { pen, pencil, dot, eraser }

class StrokeModel {
  StrokeModel({
    required this.kind,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
  });

  final StrokeKind kind;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;

  StrokeModel copyWith({
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    double? opacity,
  }) {
    return StrokeModel(
      kind: kind,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
    );
  }
}
