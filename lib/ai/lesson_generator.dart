import 'ai_service.dart';
import 'models/lesson_model.dart';

class LessonGenerator {
  LessonGenerator(this._service);

  final AIService _service;

  Future<void> generateLessonStream({
    required LessonRequest request,
    required void Function(String chunk) onChunk,
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    await _service.postStream(
      path: "/generate_lesson",
      body: request.toJson(),
      onChunk: onChunk,
      onError: onError,
      onDone: onDone,
      timeout: const Duration(seconds: 45),
      maxRetries: 2,
    );
  }

  Future<void> cancel() => _service.cancel();
}
