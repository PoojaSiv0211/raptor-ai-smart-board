import 'package:flutter/material.dart';

class CropPreviewPainter extends CustomPainter {
  const CropPreviewPainter({
    this.preview,
    this.existingCrop,
  });

  final Rect? preview;
  final Rect? existingCrop;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw existing crop area with a subtle overlay
    if (existingCrop != null) {
      final paint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;
      
      final borderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRect(existingCrop!, paint);
      canvas.drawRect(existingCrop!, borderPaint);
    }

    // Draw preview crop area
    if (preview != null) {
      final paint = Paint()
        ..color = Colors.red.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      
      final borderPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeDashArray = [5, 5];

      canvas.drawRect(preview!, paint);
      canvas.drawRect(preview!, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CropPreviewPainter oldDelegate) {
    return oldDelegate.preview != preview || 
           oldDelegate.existingCrop != existingCrop;
  }
}

extension on Paint {
  set strokeDashArray(List<double> dashArray) {
    // Simple dash effect - Flutter doesn't have built-in dash support
    // This is a placeholder for the dash effect
  }
}