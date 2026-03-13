import 'package:flutter/foundation.dart';

import 'ai_service.dart';
import 'lesson_generator.dart';
import 'quiz_generator.dart';
import 'models/lesson_model.dart';
import 'models/quiz_model.dart';

class AIState {
  const AIState({
    required this.isGenerating,
    required this.currentText,
    required this.errorState,
    required this.requestProgress,
  });

  final bool isGenerating;
  final String currentText;
  final String? errorState;
  final double requestProgress;

  AIState copyWith({
    bool? isGenerating,
    String? currentText,
    String? errorState,
    double? requestProgress,
  }) {
    return AIState(
      isGenerating: isGenerating ?? this.isGenerating,
      currentText: currentText ?? this.currentText,
      errorState: errorState,
      requestProgress: requestProgress ?? this.requestProgress,
    );
  }

  static const initial = AIState(
    isGenerating: false,
    currentText: "",
    errorState: null,
    requestProgress: 0,
  );
}

class AIController extends ChangeNotifier {
  AIController({required String baseUrl})
    : _lesson = LessonGenerator(AIService(baseUrl: baseUrl)),
      _quiz = QuizGenerator(AIService(baseUrl: baseUrl));

  // Each generator has its own service instance so cancel is predictable per tool.
  final LessonGenerator _lesson;
  final QuizGenerator _quiz;

  AIState state = AIState.initial;

  LessonRequest? _lastLessonReq;
  QuizRequest? _lastQuizReq;

  void _set(AIState s) {
    state = s;
    notifyListeners();
  }

  void resetOutput() {
    _set(AIState.initial);
  }

  Future<void> cancel() async {
    await _lesson.cancel();
    await _quiz.cancel();

    _set(
      state.copyWith(
        isGenerating: false,
        errorState: "Cancelled",
        requestProgress: 0,
      ),
    );
  }

  Future<void> generateLesson(LessonRequest req) async {
    _lastLessonReq = req;

    _set(
      const AIState(
        isGenerating: true,
        currentText: "",
        errorState: null,
        requestProgress: 0,
      ),
    );

    await _lesson.generateLessonStream(
      request: req,
      onChunk: (chunk) {
        _set(
          state.copyWith(
            currentText: state.currentText + chunk,
            errorState: null,
            requestProgress: 0.2,
          ),
        );
      },
      onError: (msg) {
        _set(
          state.copyWith(
            isGenerating: false,
            errorState: msg,
            requestProgress: 0,
          ),
        );
      },
      onDone: () {
        _set(
          state.copyWith(
            isGenerating: false,
            errorState: null,
            requestProgress: 1,
          ),
        );
      },
    );
  }

  Future<void> retryLesson() async {
    final last = _lastLessonReq;
    if (last != null) await generateLesson(last);
  }

  Future<void> generateQuiz(QuizRequest req) async {
    _lastQuizReq = req;

    _set(
      const AIState(
        isGenerating: true,
        currentText: "",
        errorState: null,
        requestProgress: 0,
      ),
    );

    await _quiz.generateQuizStream(
      request: req,
      onChunk: (chunk) {
        _set(
          state.copyWith(
            currentText: state.currentText + chunk,
            errorState: null,
            requestProgress: 0.2,
          ),
        );
      },
      onError: (msg) {
        _set(
          state.copyWith(
            isGenerating: false,
            errorState: msg,
            requestProgress: 0,
          ),
        );
      },
      onDone: () {
        _set(
          state.copyWith(
            isGenerating: false,
            errorState: null,
            requestProgress: 1,
          ),
        );
      },
    );
  }

  Future<void> retryQuiz() async {
    final last = _lastQuizReq;
    if (last != null) await generateQuiz(last);
  }
}
