import 'dart:math';
import 'package:flutter/material.dart';
import '../drawing_controller.dart';
import '../models/text_model.dart';
import 'drawing_tool.dart';

class FormulaTool extends DrawingTool {
  FormulaTool(this.controller);

  final DrawingController controller;

  // Formula tool is “panel driven”, so gestures can be ignored
  @override
  void onStart(Offset point) {}

  @override
  void onUpdate(Offset point) {}

  @override
  void onEnd() {}

  @override
  void paint(Canvas canvas) {}
}

/// Floating formula panel widget
class FormulaPanel extends StatelessWidget {
  const FormulaPanel({super.key, required this.controller});

  final DrawingController controller;

  static const symbols = [
    'π',
    'θ',
    '√',
    '∑',
    '∫',
    '∞',
    '≈',
    '≠',
    '≤',
    '≥',
    '+',
    '−',
    '×',
    '÷',
    '=',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    '^',
    '_',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Formula",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in symbols)
                  InkWell(
                    onTap: () {
                      final id =
                          "${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}";
                      controller.addText(
                        TextModel(
                          id: id,
                          text: s,
                          position: const Offset(200, 150),
                          fontSize: 26,
                          color: controller.color,
                        ),
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F5FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Text(s, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
