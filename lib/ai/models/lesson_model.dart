class LessonRequest {
  LessonRequest({required this.topic, required this.grade});

  final String topic;
  final int grade;

  Map<String, dynamic> toJson() => {"topic": topic, "grade": grade};
}

class LessonResult {
  LessonResult({required this.text, required this.topic, required this.grade});

  final String text;
  final String topic;
  final int grade;

  Map<String, dynamic> toJson() => {
    "text": text,
    "topic": topic,
    "grade": grade,
  };

  factory LessonResult.fromJson(Map<String, dynamic> json) {
    return LessonResult(
      text: (json["text"] ?? "").toString(),
      topic: (json["topic"] ?? "").toString(),
      grade: (json["grade"] ?? 0) is int
          ? json["grade"] as int
          : int.tryParse((json["grade"] ?? "0").toString()) ?? 0,
    );
  }
}
