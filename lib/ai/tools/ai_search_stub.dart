import 'ai_tool.dart';

class AISearchStub implements AITool {
  @override
  String get id => "ai_search";

  @override
  String get title => "AI Search (Stub)";

  @override
  Future<void> init() async {
    // Future: semantic search across board content and saved sessions
  }
}
