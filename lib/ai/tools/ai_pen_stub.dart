import 'ai_tool.dart';

class AIPenStub implements AITool {
  @override
  String get id => "ai_pen";

  @override
  String get title => "AI Pen (Stub)";

  @override
  Future<void> init() async {
    // Future: smart stroke smoothing, shape detection, handwriting to text, etc.
  }
}
