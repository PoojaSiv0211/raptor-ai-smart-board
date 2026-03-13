import 'package:flutter/material.dart';

class SpotlightOverlay extends StatelessWidget {
  const SpotlightOverlay({
    super.key,
    required this.enabled,
    required this.position,
    required this.radius,
    this.darkness = 0.55,
  });

  final bool enabled;
  final Offset position;
  final double radius;
  final double darkness;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _SpotlightPainter(
            position: position,
            radius: radius,
            darkness: darkness,
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.position,
    required this.radius,
    required this.darkness,
  });

  final Offset position;
  final double radius;
  final double darkness;

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = Colors.black.withOpacity(darkness);

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, darkPaint);

    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(position, radius, clear);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.radius != radius ||
        oldDelegate.darkness != darkness;
  }
}
