import 'dart:ui';

class TextModel {
  TextModel({
    required this.id,
    required this.text,
    required this.position,
    this.fontSize = 22,
    this.color = const Color(0xFF111111),
  });

  final String id;
  final String text;
  final Offset position;
  final double fontSize;
  final Color color;

  TextModel copyWith({
    String? text,
    Offset? position,
    double? fontSize,
    Color? color,
  }) {
    return TextModel(
      id: id,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
    );
  }
}
