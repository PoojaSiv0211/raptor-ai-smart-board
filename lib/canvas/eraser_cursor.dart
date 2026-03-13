import 'package:flutter/material.dart';

class EraserCursor extends StatelessWidget {
  const EraserCursor({
    super.key,
    required this.position,
    required this.radius,
    required this.isVisible,
  });

  final Offset position;
  final double radius;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    return Positioned(
      left: position.dx - radius,
      top: position.dy - radius,
      child: IgnorePointer(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.8),
              width: 2,
            ),
            color: Colors.red.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }
}