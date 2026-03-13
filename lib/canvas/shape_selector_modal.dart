import 'package:flutter/material.dart';
import 'drawables.dart';
import 'color_picker_modal.dart';

Future<ShapeConfig?> showShapeSelector(BuildContext context, ShapeType currentShape, Color currentColor) {
  return showDialog<ShapeConfig>(
    context: context,
    builder: (context) => _ShapeSelectorDialog(
      currentShape: currentShape,
      currentColor: currentColor,
    ),
  );
}

class ShapeConfig {
  const ShapeConfig({
    required this.shape,
    required this.color,
  });
  
  final ShapeType shape;
  final Color color;
}

class _ShapeSelectorDialog extends StatefulWidget {
  const _ShapeSelectorDialog({
    required this.currentShape,
    required this.currentColor,
  });
  
  final ShapeType currentShape;
  final Color currentColor;

  @override
  State<_ShapeSelectorDialog> createState() => _ShapeSelectorDialogState();
}

class _ShapeSelectorDialogState extends State<_ShapeSelectorDialog> {
  late ShapeType selectedShape;
  late Color selectedColor;

  @override
  void initState() {
    super.initState();
    selectedShape = widget.currentShape;
    selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Shape & Color'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shape selection
            const Text(
              'Shape',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: ShapeType.values.length,
              itemBuilder: (context, index) {
                final shape = ShapeType.values[index];
                final isSelected = shape == selectedShape;
                
                return GestureDetector(
                  onTap: () => setState(() => selectedShape = shape),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? selectedColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? selectedColor : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(40, 40),
                          painter: _ShapePreviewPainter(shape, selectedColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getShapeName(shape),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? selectedColor : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Color selection
            const Text(
              'Color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            ColorPalette(
              selected: selectedColor,
              onSelect: (color) => setState(() => selectedColor = color),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(
            ShapeConfig(shape: selectedShape, color: selectedColor),
          ),
          child: const Text('Select'),
        ),
      ],
    );
  }

  String _getShapeName(ShapeType shape) {
    switch (shape) {
      case ShapeType.rectangle:
        return 'Rectangle';
      case ShapeType.roundedRect:
        return 'Rounded';
      case ShapeType.circle:
        return 'Circle';
      case ShapeType.ellipse:
        return 'Ellipse';
      case ShapeType.triangle:
        return 'Triangle';
      case ShapeType.diamond:
        return 'Diamond';
      case ShapeType.line:
        return 'Line';
      case ShapeType.arrow:
        return 'Arrow';
    }
  }
}

class _ShapePreviewPainter extends CustomPainter {
  const _ShapePreviewPainter(this.shape, this.color);
  
  final ShapeType shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final center = rect.center;

    switch (shape) {
      case ShapeType.rectangle:
        canvas.drawRect(rect, paint);
        break;
      case ShapeType.roundedRect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          paint,
        );
        break;
      case ShapeType.circle:
        canvas.drawCircle(center, rect.shortestSide / 2, paint);
        break;
      case ShapeType.ellipse:
        canvas.drawOval(rect, paint);
        break;
      case ShapeType.triangle:
        final path = Path()
          ..moveTo(center.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.diamond:
        final path = Path()
          ..moveTo(center.dx, rect.top)
          ..lineTo(rect.right, center.dy)
          ..lineTo(center.dx, rect.bottom)
          ..lineTo(rect.left, center.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.line:
        canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
        break;
      case ShapeType.arrow:
        canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
        // Arrow head
        final arrowSize = 6.0;
        final angle = (rect.bottomRight - rect.topLeft).direction;
        final arrowPoint1 = rect.bottomRight + Offset.fromDirection(angle + 2.5, arrowSize);
        final arrowPoint2 = rect.bottomRight + Offset.fromDirection(angle - 2.5, arrowSize);
        canvas.drawLine(rect.bottomRight, arrowPoint1, paint);
        canvas.drawLine(rect.bottomRight, arrowPoint2, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePreviewPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}