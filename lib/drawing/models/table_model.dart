import 'dart:ui';

class TableModel {
  TableModel({
    required this.origin,
    required this.rows,
    required this.cols,
    required this.cellWidth,
    required this.cellHeight,
    required this.color,
    required this.strokeWidth,
  });

  final Offset origin;
  final int rows;
  final int cols;
  final double cellWidth;
  final double cellHeight;
  final Color color;
  final double strokeWidth;

  Size get size => Size(cols * cellWidth, rows * cellHeight);
  Rect get rect => origin & size;
}
