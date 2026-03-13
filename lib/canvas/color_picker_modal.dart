import 'package:flutter/material.dart';

class ColorPalette extends StatelessWidget {
  const ColorPalette({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final Color selected;
  final ValueChanged<Color> onSelect;

  static const colors = <Color>[
    Colors.black,
    Colors.white,
    Color(0xFFEF4444), // red
    Color(0xFFF59E0B), // amber
    Color(0xFF22C55E), // green
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFF64748B), // slate
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in colors)
          InkWell(
            onTap: () => onSelect(c),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c.value == selected.value ? Colors.red : Colors.black12,
                  width: c.value == selected.value ? 3 : 1,
                ),
              ),
            ),
          )
      ],
    );
  }
}

Future<Color?> showColorPickerModal(BuildContext context, Color currentColor) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(currentColor: currentColor),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.currentColor});
  
  final Color currentColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color selectedColor;

  @override
  void initState() {
    super.initState();
    selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a Color'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current color preview
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 16),
            
            // Color palette
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
          onPressed: () => Navigator.of(context).pop(selectedColor),
          child: const Text('Select'),
        ),
      ],
    );
  }
}