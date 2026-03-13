import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai_controller.dart';
import 'models/quiz_model.dart';

Future<void> showQuizModal({
  required BuildContext context,
  required String baseUrl,
}) async {
  final ai = AIController(baseUrl: baseUrl);

  final topicCtrl = TextEditingController();

  String questionCountStr = "5";
  String marksStr = "1";
  QuizType selectedType = QuizType.mcq;
  bool revealAnswers = false;

  String maskAnswers(String text, bool reveal) {
    if (reveal) return text;

    // Normalize line for checking: remove markdown symbols and extra spaces
    String norm(String s) => s
        .toLowerCase()
        .replaceAll('*', '')
        .replaceAll('_', '')
        .replaceAll('`', '')
        .trim();

    final lines = text.split('\n');

    bool hidingKeyPointsBlock = false;

    final out = <String>[];
    for (final raw in lines) {
      final n = norm(raw);

      // If we enter "Key Points" block, hide until a blank line or next question
      if (n.startsWith('key points:')) {
        hidingKeyPointsBlock = true;
        continue;
      }

      if (hidingKeyPointsBlock) {
        // Stop hiding when a new question begins or empty line
        if (n.isEmpty ||
            RegExp(r'^q\d+\)').hasMatch(n) ||
            RegExp(r'^\d+\)').hasMatch(n)) {
          hidingKeyPointsBlock = false;
        } else {
          // continue hiding bullets/lines inside key points
          continue;
        }
      }

      // Hide any line that contains these labels, even with markdown like **Answer:**
      final isAnswerLine = RegExp(
        r'^(answer|expected answer|explanation|hint)\s*[:\-]',
      ).hasMatch(n);
      final isInlineAnswer = RegExp(
        r'\b(answer|expected answer|explanation|hint)\s*[:\-]',
      ).hasMatch(n);

      // Also hide bullet lines ONLY if they are clearly part of answers/explanations
      final isBullet = n.startsWith('- ') || n.startsWith('• ');

      if (isAnswerLine || isInlineAnswer) {
        continue;
      }

      // Optional: if the model outputs explanation bullets after an Explanation label,
      // we already hid the label line; bullets could still remain.
      // We'll hide bullets that immediately follow a hidden label by tracking, but
      // for simplicity, keep bullets unless they're very likely answer content.
      // Here we hide bullets that look like "correct option" / "because" etc.
      if (isBullet &&
          (n.contains('correct') ||
              n.contains('because') ||
              n.contains('therefore'))) {
        continue;
      }

      out.add(raw);
    }

    // Clean multiple blank lines left by removals
    final cleaned = out
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trimRight();
    return cleaned.isEmpty
        ? "Quiz generated. Tap 'Reveal Answers' to view answers."
        : cleaned;
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          return Dialog(
            child: SizedBox(
              width: 720,
              height: 520,
              child: AnimatedBuilder(
                animation: ai,
                builder: (context, _) {
                  final s = ai.state;
                  final isGenerating = s.isGenerating;

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "AI Quiz Generator",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: topicCtrl,
                                decoration: const InputDecoration(
                                  labelText: "Topic",
                                  hintText: "e.g. Photosynthesis",
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            SizedBox(
                              width: 130,
                              child: DropdownButtonFormField<String>(
                                value: questionCountStr,
                                items: const [
                                  DropdownMenuItem(
                                    value: "5",
                                    child: Text("5 Qs"),
                                  ),
                                  DropdownMenuItem(
                                    value: "10",
                                    child: Text("10 Qs"),
                                  ),
                                  DropdownMenuItem(
                                    value: "15",
                                    child: Text("15 Qs"),
                                  ),
                                ],
                                onChanged: isGenerating
                                    ? null
                                    : (v) => setLocalState(() {
                                        questionCountStr = v!;
                                      }),
                                decoration: const InputDecoration(
                                  labelText: "Questions",
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            SizedBox(
                              width: 150,
                              child: DropdownButtonFormField<String>(
                                value: marksStr,
                                items: const [
                                  DropdownMenuItem(
                                    value: "1",
                                    child: Text("1 Mark"),
                                  ),
                                  DropdownMenuItem(
                                    value: "2",
                                    child: Text("2 Marks"),
                                  ),
                                  DropdownMenuItem(
                                    value: "5",
                                    child: Text("5 Marks"),
                                  ),
                                ],
                                onChanged: isGenerating
                                    ? null
                                    : (v) => setLocalState(() {
                                        marksStr = v!;
                                      }),
                                decoration: const InputDecoration(
                                  labelText: "Marks / Question",
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<QuizType>(
                          value: selectedType,
                          items: const [
                            DropdownMenuItem(
                              value: QuizType.mcq,
                              child: Text("MCQ"),
                            ),
                            DropdownMenuItem(
                              value: QuizType.shortAnswer,
                              child: Text("Short Answer"),
                            ),
                            DropdownMenuItem(
                              value: QuizType.trueFalse,
                              child: Text("True / False"),
                            ),
                            DropdownMenuItem(
                              value: QuizType.fillBlank,
                              child: Text("Fill in the Blank"),
                            ),
                          ],
                          onChanged: isGenerating
                              ? null
                              : (v) => setLocalState(() {
                                  selectedType = v!;
                                }),
                          decoration: const InputDecoration(
                            labelText: "Quiz Type",
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (isGenerating) const LinearProgressIndicator(),
                        if (isGenerating) const SizedBox(height: 10),

                        if (s.errorState != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFEF9A9A),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(s.errorState!)),
                                TextButton(
                                  onPressed: isGenerating ? null : ai.retryQuiz,
                                  child: const Text("Retry"),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),

                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                s.currentText.isEmpty
                                    ? "Your quiz will appear here..."
                                    : maskAnswers(s.currentText, revealAnswers),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: s.currentText.isEmpty
                                  ? null
                                  : () => setLocalState(() {
                                      revealAnswers = !revealAnswers;
                                    }),
                              child: Text(
                                revealAnswers
                                    ? "Hide Answers"
                                    : "Reveal Answers",
                              ),
                            ),
                            const SizedBox(width: 10),

                            TextButton(
                              onPressed: s.currentText.isEmpty
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: s.currentText),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(content: Text("Copied")),
                                      );
                                    },
                              child: const Text("Copy"),
                            ),
                            const SizedBox(width: 10),

                            TextButton(
                              onPressed: isGenerating ? ai.cancel : null,
                              child: const Text("Cancel"),
                            ),
                            const SizedBox(width: 10),

                            TextButton(
                              onPressed: isGenerating
                                  ? null
                                  : () {
                                      ai.dispose();
                                      Navigator.pop(context);
                                    },
                              child: const Text("Close"),
                            ),
                            const SizedBox(width: 10),

                            ElevatedButton(
                              onPressed: isGenerating
                                  ? null
                                  : () async {
                                      final topic = topicCtrl.text.trim();

                                      if (topic.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text("Enter a topic."),
                                          ),
                                        );
                                        return;
                                      }

                                      ai.resetOutput();
                                      setLocalState(
                                        () => revealAnswers = false,
                                      );

                                      await ai.generateQuiz(
                                        QuizRequest(
                                          topic: topic,
                                          questionCount: int.parse(
                                            questionCountStr,
                                          ),
                                          marksPerQuestion: int.parse(marksStr),
                                          type: selectedType,
                                        ),
                                      );
                                    },
                              child: Text(
                                isGenerating ? "Generating..." : "Generate",
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    },
  );
}
