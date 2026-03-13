import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_config.dart';

class ImageSearchResult {
  final String title;
  final String imageUrl;
  final String thumbnailUrl;
  final String sourceUrl;

  ImageSearchResult({
    required this.title,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.sourceUrl,
  });
}

class ImageSearchService {
  Future<List<ImageSearchResult>> search(
    String query, {
    int maxResults = 10,
  }) async {
    final uri = Uri.parse("${AIConfig.baseUrl}/search_images").replace(
      queryParameters: {'q': query, 'max_results': maxResults.toString()},
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        "Image search failed: ${response.statusCode} ${response.body}",
      );
    }

    final data = jsonDecode(response.body);
    final items = (data["items"] as List?) ?? [];

    return items.map((item) {
      return ImageSearchResult(
        title: item["title"] ?? "Image",
        imageUrl: item["imageUrl"] ?? "",
        thumbnailUrl: item["thumbnailUrl"] ?? (item["imageUrl"] ?? ""),
        sourceUrl: item["sourceUrl"] ?? "",
      );
    }).toList();
  }
}
