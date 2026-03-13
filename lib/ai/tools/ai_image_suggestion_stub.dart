import 'ai_tool.dart';

class AIImageSuggestionStub implements AITool {
  @override
  String get id => "ai_image_suggestion";

  @override
  String get title => "AI Image Suggestion (Stub)";

  @override
  Future<void> init() async {
    // Future: suggest diagrams/images for the current lesson topic
  }
}
