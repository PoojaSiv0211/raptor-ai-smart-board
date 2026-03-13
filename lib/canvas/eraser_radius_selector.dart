import 'package:flutter/material.dart';

class EraserRadiusSelector extends StatelessWidget {
  const EraserRadiusSelector({
    super.key,
    required this.currentRadius,
    required this.onRadiusChanged,
  });

  final double currentRadius;
  final ValueChanged<double> onRadiusChanged;

  static const List<double> radiusOptions = [8, 12, 16, 22, 28, 35, 42, 50];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio_button_unchecked, size: 16, color: Colors.red),
            const SizedBox(width: 8),
            ...radiusOptions.map((radius) {
              final isSelected = (currentRadius - radius).abs() < 0.1;
              return GestureDetector(
                onTap: () => onRadiusChanged(radius),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.red.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isSelected ? Border.all(color: Colors.red, width: 1) : null,
                  ),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.withValues(alpha: 0.6), width: 1),
                    ),
                    child: Center(
                      child: Container(
                        width: (radius / 50 * 16).clamp(4, 16),
                        height: (radius / 50 * 16).clamp(4, 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            Text(
              '${currentRadius.round()}px',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}