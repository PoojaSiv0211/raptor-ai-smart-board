import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

typedef InsertToBoardCallback = Future<void> Function(String text);

Future<void> showAiSearchModal(
  BuildContext context, {
  required InsertToBoardCallback onInsertToBoard,
}) async {
  final rootCtx = Navigator.of(context, rootNavigator: true).context;

  await showDialog(
    context: rootCtx,
    barrierDismissible: true,
    builder: (_) => _AiSearchDialog(onInsertToBoard: onInsertToBoard),
  );
}

class _AiSearchDialog extends StatefulWidget {
  const _AiSearchDialog({required this.onInsertToBoard});

  final InsertToBoardCallback onInsertToBoard;

  @override
  State<_AiSearchDialog> createState() => _AiSearchDialogState();
}

class _AiSearchDialogState extends State<_AiSearchDialog> {
  final _topicCtrl = TextEditingController();
  int _selectedClass = 6;

  bool _loading = false;
  String? _error;
  String _resultText = "";

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _topicCtrl.clear();
      _selectedClass = 6;
      _loading = false;
      _error = null;
      _resultText = "";
    });
  }

  Future<void> _copy() async {
    if (_resultText.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _resultText));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Copied ✅")));
  }

  Future<void> _insertToBoard() async {
    if (_resultText.trim().isEmpty) return;
    await widget.onInsertToBoard(_resultText);
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pop(); // close modal after insert
  }

  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = "Enter a topic.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultText = "";
    });

    try {
      // ✅ Wikipedia summary (no API key). Works as reliable fallback.
      final safeTopic = Uri.encodeComponent(topic);
      final uri = Uri.parse(
        "https://en.wikipedia.org/api/rest_v1/page/summary/$safeTopic",
      );

      final res = await http.get(uri, headers: {"accept": "application/json"});

      if (res.statusCode != 200) {
        throw Exception(
          "No info found (status ${res.statusCode}). Try another topic.",
        );
      }

      final data = jsonDecode(res.body);
      final title = (data["title"] ?? topic).toString();
      final extract = (data["extract"] ?? "").toString().trim();
      if (extract.isEmpty) {
        throw Exception("No summary available. Try a different topic.");
      }

      final definition = _makeDefinition(extract, _selectedClass);
      final examples = _makeExamples(title, _selectedClass);
      final general = _makeGeneralInfo(extract, _selectedClass);

      final out = StringBuffer()
        ..writeln("Topic: $title")
        ..writeln("Class: $_selectedClass")
        ..writeln("")
        ..writeln("Definition:")
        ..writeln(definition)
        ..writeln("")
        ..writeln("Examples:")
        ..writeln(examples)
        ..writeln("")
        ..writeln("General Information:")
        ..writeln(general);

      setState(() => _resultText = out.toString());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _makeDefinition(String extract, int grade) {
    // Make it simpler for lower classes
    if (grade <= 5) {
      return _simplify(extract, maxSentences: 2);
    }
    if (grade <= 8) {
      return _simplify(extract, maxSentences: 3);
    }
    return _simplify(extract, maxSentences: 4);
  }

  String _makeExamples(String title, int grade) {
    // Simple example templates (good enough for “basic definition + examples”)
    if (grade <= 5) {
      return "- A simple real-life example of $title.\n"
          "- Where you might see $title in daily life.\n"
          "- A small question: “What is $title?”";
    }
    if (grade <= 8) {
      return "- Real-life example of $title.\n"
          "- A textbook-style example related to $title.\n"
          "- A quick practice question about $title.";
    }
    return "- Real-world application of $title.\n"
        "- Conceptual example showing how $title works.\n"
        "- One short practice problem idea based on $title.";
  }

  String _makeGeneralInfo(String extract, int grade) {
    if (grade <= 5) return _simplify(extract, maxSentences: 3);
    if (grade <= 8) return _simplify(extract, maxSentences: 4);
    return _simplify(extract, maxSentences: 5);
  }

  String _simplify(String text, {required int maxSentences}) {
    final cleaned = text.replaceAll(RegExp(r"\s+"), " ").trim();
    final sentences = cleaned.split(RegExp(r"(?<=[.!?])\s+"));
    final take = sentences.take(maxSentences).toList();
    return take.join(" ");
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("AI Search"),
      content: SizedBox(
        width: 900,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _topicCtrl,
                    onSubmitted: (_) => _generate(),
                    decoration: const InputDecoration(
                      labelText: "Topic",
                      hintText: "Enter a topic (e.g., Linear Regression)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<int>(
                    value: _selectedClass,
                    decoration: const InputDecoration(
                      labelText: "Class",
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text("Class $c"),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedClass = v ?? 6),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _generate,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Generate"),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            if (_resultText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                height: 360,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _resultText,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _clear, child: const Text("Clear")),
        TextButton(
          onPressed: _resultText.trim().isEmpty ? null : _copy,
          child: const Text("Copy"),
        ),
        ElevatedButton(
          onPressed: _resultText.trim().isEmpty ? null : _insertToBoard,
          child: const Text("Insert to Board"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
