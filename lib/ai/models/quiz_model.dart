enum QuizType { shortAnswer, mcq, trueFalse, fillBlank }

class QuizRequest {
  QuizRequest({
    required this.topic,
    required this.questionCount,
    required this.marksPerQuestion,
    required this.type,
  });

  final String topic;
  final int questionCount;
  final int marksPerQuestion;
  final QuizType type;

  Map<String, dynamic> toJson() => {
    "topic": topic,
    "questionCount": questionCount,
    "marksPerQuestion": marksPerQuestion,
    "type": type.name,
  };
}

class QuizResult {
  QuizResult({
    required this.text,
    required this.topic,
    required this.questionCount,
    required this.marksPerQuestion,
    required this.type,
  });

  final String text;
  final String topic;
  final int questionCount;
  final int marksPerQuestion;
  final QuizType type;
}
