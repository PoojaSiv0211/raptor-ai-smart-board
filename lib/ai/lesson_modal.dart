import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai_controller.dart';
import 'models/lesson_model.dart';

Future<void> showLessonModal({
  required BuildContext context,
  required String baseUrl,
}) async {
  final ai = AIController(baseUrl: baseUrl);
  final topicCtrl = TextEditingController();

  int grade = 8;

  try {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
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
                        "AI Lesson Generator",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ---------------- TOP INPUT ROW ----------------
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: topicCtrl,
                              enabled: !isGenerating,
                              decoration: const InputDecoration(
                                labelText: "Topic",
                                hintText: "e.g. Solar System / Photosynthesis",
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Grade
                          SizedBox(
                            width: 160,
                            child: DropdownButtonFormField<int>(
                              value: grade,
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text("Grade ${i + 1}"),
                                ),
                              ),
                              onChanged: isGenerating
                                  ? null
                                  : (v) {
                                      if (v != null) grade = v;
                                    },
                              decoration: const InputDecoration(
                                labelText: "Grade",
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ---------------- PROGRESS ----------------
                      if (isGenerating) const LinearProgressIndicator(),
                      if (isGenerating) const SizedBox(height: 10),

                      // ---------------- ERROR ----------------
                      if (s.errorState != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF9A9A)),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(s.errorState!)),
                              TextButton(
                                onPressed: isGenerating ? null : ai.retryLesson,
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      // ---------------- OUTPUT BOX ----------------
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
                                  ? "Your lesson will appear here..."
                                  : s.currentText,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ---------------- BUTTONS ----------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
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

                          TextButton(
                            onPressed: s.currentText.isEmpty
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: s.currentText),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(content: Text("Copied")),
                                      );
                                    }
                                  },
                            child: const Text("Copy"),
                          ),
                          const SizedBox(width: 10),

                          TextButton(
                            onPressed: isGenerating ? ai.cancel : null,
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 10),

                          OutlinedButton(
                            onPressed: isGenerating
                                ? null
                                : () {
                                    topicCtrl.clear();
                                    ai.resetOutput();
                                  },
                            child: const Text("New Lesson"),
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

                                    await ai.generateLesson(
                                      LessonRequest(topic: topic, grade: grade),
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
  } finally {
    topicCtrl.dispose();
  }
}
