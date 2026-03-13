import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class WikiResult {
  WikiResult({
    required this.title,
    required this.summary,
    required this.sourceUrl,
  });

  final String title;
  final String summary;
  final String sourceUrl;
}

class FreeAiService {
  FreeAiService({http.Client? client, this.circleSearchEndpoint})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? circleSearchEndpoint;

  static const Map<String, String> _headers = {
    'accept': 'application/json',
    'user-agent': 'RaptorCircleSearch/1.0',
  };

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'accept': 'application/json',
  };

  /// MAIN FUNCTION USED BY CIRCLE SEARCH
  Future<String> circleSearchFromImageBytes(Uint8List imageBytes) async {
    final topic = await extractTopicFromImageBytes(imageBytes);

    if (topic == null || topic.trim().isEmpty) {
      throw Exception('Could not detect readable text.');
    }

    final wiki = await fetchWiki(topic.trim());

    return buildStudyNotes(wiki);
  }

  /// GET TEXT FROM BACKEND OCR
  Future<String?> extractTopicFromImageBytes(Uint8List imageBytes) async {
    final endpoint = circleSearchEndpoint;

    if (endpoint == null || endpoint.isEmpty) {
      throw Exception("circleSearchEndpoint not configured");
    }

    final uri = Uri.parse(endpoint);

    final payload = {"image_base64": base64Encode(imageBytes)};

    final res = await _client.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception("Circle search backend failed");
    }

    final data = jsonDecode(res.body);

    if (data is! Map) return null;

    return data["topic"] ?? data["query"] ?? data["text"] ?? data["result"];
  }

  /// FETCH WIKIPEDIA SUMMARY
  Future<WikiResult> fetchWiki(String topic) async {
    final encoded = Uri.encodeComponent(topic);

    final url = Uri.parse(
      "https://en.wikipedia.org/api/rest_v1/page/summary/$encoded",
    );

    final res = await _client.get(url, headers: _headers);

    if (res.statusCode != 200) {
      throw Exception("Wikipedia fetch failed");
    }

    final data = jsonDecode(res.body);

    final title = data["title"] ?? topic;
    final summary = data["extract"] ?? "";
    final source =
        "https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}";

    return WikiResult(title: title, summary: summary, sourceUrl: source);
  }

  /// FORMAT STUDY NOTES (NO EMOJIS)
  String buildStudyNotes(WikiResult w) {
    final summary = _shorten(w.summary);

    return '''
${w.title}

Explanation:
$summary

Key Points:
• ${w.title} is an important concept in its subject area.
• It has specific structures or features that define how it works.
• It performs important functions within its system.
• Understanding ${w.title} helps explain real-world processes.

Source: ${w.sourceUrl}
''';
  }

  /// SHORTEN WIKIPEDIA TEXT
  String _shorten(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (sentences.length <= 2) {
      return text;
    }

    return "${sentences[0]} ${sentences[1]}";
  }

  void dispose() {
    _client.close();
  }
}
