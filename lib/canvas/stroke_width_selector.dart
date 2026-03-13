import 'package:flutter/material.dart';

class StrokeWidthSelector extends StatefulWidget {
  const StrokeWidthSelector({
    super.key,
    required this.currentWidth,
    required this.currentColor,
    required this.onWidthChanged,
    required this.onColorChanged,
    this.onApply,
  });

  final double currentWidth;
  final Color currentColor;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback? onApply;

  @override
  State<StrokeWidthSelector> createState() => _StrokeWidthSelectorState();
}

class _StrokeWidthSelectorState extends State<StrokeWidthSelector> {
  late double _selectedWidth;
  late Color _selectedColor;

  final List<double> _strokeOptions = <double>[
    1,
    2,
    4,
    6,
    8,
    10,
    12,
    16,
    20,
    24,
  ];

  final List<Color> _colors = <Color>[
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.blue,
    Colors.deepPurple,
    Colors.pink,
    Colors.teal,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _selectedWidth = widget.currentWidth;
    _selectedColor = widget.currentColor;
  }

  @override
  void didUpdateWidget(covariant StrokeWidthSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentWidth != widget.currentWidth) {
      _selectedWidth = widget.currentWidth;
    }
    if (oldWidget.currentColor != widget.currentColor) {
      _selectedColor = widget.currentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(20),
      color: Colors.transparent,
      child: Container(
        width: 640,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              color: Colors.black26,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Color',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: _colors.map((color) {
                final isSelected = _selectedColor.value == color.value;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                    widget.onColorChanged(color);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Colors.redAccent
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Stroke Width',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _strokeOptions.map((width) {
                final isSelected = (_selectedWidth - width).abs() < 0.01;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWidth = width;
                    });
                    widget.onWidthChanged(width);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.black : cs.outlineVariant,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: width,
                        height: width,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: widget.onApply,
                icon: const Icon(Icons.check),
                label: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
