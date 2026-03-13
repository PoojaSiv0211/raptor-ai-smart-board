import 'dart:math';
import 'package:flutter/material.dart';
import 'canvas_manager.dart';
import 'drawables.dart';

class FormulaPanel extends StatelessWidget {
  const FormulaPanel({
    super.key, 
    required this.canvasManager,
    required this.onSymbolSelected,
  });

  final CanvasManager canvasManager;
  final VoidCallback onSymbolSelected;

  static const symbols = [
    // Basic math
    '+', '−', '×', '÷', '=', '≠', '≈', '±',
    // Fractions and powers
    '½', '¼', '¾', '²', '³', 'ⁿ', '₁', '₂',
    // Greek letters
    'α', 'β', 'γ', 'δ', 'θ', 'λ', 'μ', 'π', 'σ', 'φ', 'ψ', 'ω',
    // Advanced math
    '√', '∛', '∞', '∑', '∏', '∫', '∂', '∇',
    // Geometry
    '°', '∠', '⊥', '∥', '△', '□', '○', '◊',
    // Logic and sets
    '∧', '∨', '¬', '∈', '∉', '⊂', '⊃', '∪', '∩', '∅',
    // Brackets
    '(', ')', '[', ']', '{', '}', '⟨', '⟩',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 400),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.functions, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Formula Symbols',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => onSymbolSelected(),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 1.0,
                ),
                itemCount: symbols.length,
                itemBuilder: (context, index) {
                  final symbol = symbols[index];
                  return _SymbolButton(
                    symbol: symbol,
                    onTap: () => _addSymbolToCanvas(symbol),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap a symbol to add it to the canvas',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addSymbolToCanvas(String symbol) {
    // Add the symbol as a text item to the canvas
    final textItem = TextItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}',
      zIndex: canvasManager.nextZ(),
      text: symbol,
      position: const Offset(200, 200), // Default position, user can move it
      fontSize: 24,
      color: canvasManager.color,
    );

    canvasManager.addItem(textItem);
    onSymbolSelected(); // Close the panel
  }
}

class _SymbolButton extends StatelessWidget {
  const _SymbolButton({
    required this.symbol,
    required this.onTap,
  });

  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            symbol,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}