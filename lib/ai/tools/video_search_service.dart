import 'dart:convert';
import 'package:http/http.dart' as http;

import '../ai_config.dart';

class VideoSearchResult {
  final String title;

  // Main fields from backend
  final String videoUrl;
  final String thumbnailUrl;
  final String sourceUrl;

  // Backward-compat fields (modal still uses them)
  final String videoId;
  final String channelTitle;

  VideoSearchResult({
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.sourceUrl,
    this.videoId = "",
    this.channelTitle = "",
  });

  String get url => videoUrl;
}

class VideoSearchService {
  Future<List<VideoSearchResult>> search(
    String query, {
    int maxResults = 10,
  }) async {
    // ✅ Try multiple possible backend routes (first 200 OK wins)
    final candidates = <String>[
      "/search_videos",
      "/search-videos",
      "/video_search",
      "/search_video",
      "/videos/search",
      "/search/videos",
      "/youtube/search",
      "/search_youtube",
    ];

    http.Response? lastResp;
    Uri? lastUri;

    for (final path in candidates) {
      final uri = Uri.parse("${AIConfig.baseUrl}$path").replace(
        queryParameters: {"q": query, "max_results": maxResults.toString()},
      );

      lastUri = uri;

      try {
        final resp = await http.get(uri);
        lastResp = resp;

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);

          // Common shapes:
          // 1) { "items": [ ... ] }
          // 2) [ ... ]
          final rawItems = (data is Map && data["items"] is List)
              ? (data["items"] as List)
              : (data is List ? data : <dynamic>[]);

          final results = <VideoSearchResult>[];

          for (final item in rawItems) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(
              item.map((k, v) => MapEntry(k.toString(), v)),
            );

            // ---- YouTube Data API v3 style ----
            // id: { videoId: "..." }  OR id: "..."
            String videoId = "";
            final idVal = m["id"];
            if (idVal is Map && idVal["videoId"] != null) {
              videoId = idVal["videoId"].toString();
            } else if (idVal is String) {
              videoId = idVal;
            }

            final snippet = (m["snippet"] is Map)
                ? Map<String, dynamic>.from(
                    (m["snippet"] as Map).map(
                      (k, v) => MapEntry(k.toString(), v),
                    ),
                  )
                : <String, dynamic>{};

            final title = _firstNonEmpty([
              _asString(m["title"]),
              _asString(snippet["title"]),
              "Video",
            ]);

            final channelTitle = _firstNonEmpty([
              _asString(m["channelTitle"]),
              _asString(snippet["channelTitle"]),
              _asString(m["channel"]),
              "",
            ]);

            // thumbnails: snippet.thumbnails.high.url / medium.url / default.url
            String thumb = _asString(m["thumbnailUrl"]);
            if (thumb.isEmpty) thumb = _asString(m["thumbnail"]);
            if (thumb.isEmpty) {
              final thumbs = snippet["thumbnails"];
              if (thumbs is Map) {
                String pickThumb(Map t, String key) {
                  final v = t[key];
                  if (v is Map && v["url"] != null) return v["url"].toString();
                  return "";
                }

                // prefer higher quality
                thumb = pickThumb(thumbs, "high");
                if (thumb.isEmpty) thumb = pickThumb(thumbs, "medium");
                if (thumb.isEmpty) thumb = pickThumb(thumbs, "default");
              }
            }

            // video URL / source URL
            String videoUrl = _asString(m["videoUrl"]);
            if (videoUrl.isEmpty) videoUrl = _asString(m["url"]);
            if (videoUrl.isEmpty) videoUrl = _asString(m["link"]);
            if (videoUrl.isEmpty) videoUrl = _asString(m["video_url"]);

            // If we have a videoId but no URL, build YouTube URL
            if (videoUrl.isEmpty && videoId.isNotEmpty) {
              videoUrl = "https://www.youtube.com/watch?v=$videoId";
            }

            // If still no videoId, try extracting from URL
            if (videoId.isEmpty && videoUrl.isNotEmpty) {
              videoId = _extractYoutubeId(videoUrl);
            }

            String sourceUrl = _asString(m["sourceUrl"]);
            if (sourceUrl.isEmpty) sourceUrl = _asString(m["source_url"]);
            if (sourceUrl.isEmpty) sourceUrl = _asString(m["source"]);
            if (sourceUrl.isEmpty) sourceUrl = videoUrl;

            // If thumbnail is still empty but we have videoId, use YouTube thumbnail
            if (thumb.isEmpty && videoId.isNotEmpty) {
              // HQ thumbnail (usually works)
              thumb = "https://i.ytimg.com/vi/$videoId/hqdefault.jpg";
            }

            // Skip totally empty entries (prevents blank tiles)
            if (videoUrl.isEmpty && videoId.isEmpty && title == "Video") {
              continue;
            }

            results.add(
              VideoSearchResult(
                title: title,
                videoUrl: videoUrl,
                thumbnailUrl: thumb,
                sourceUrl: sourceUrl,
                videoId: videoId,
                channelTitle: channelTitle,
              ),
            );
          }

          return results;
        }

        if (resp.statusCode == 404) continue; // try next route
        throw Exception(
          "Video search failed at $path: ${resp.statusCode} ${resp.body}",
        );
      } catch (_) {
        continue;
      }
    }

    throw Exception(
      "Video search failed: no working endpoint found.\n"
      "Last tried: ${lastUri ?? "(none)"}\n"
      "Last response: ${lastResp?.statusCode ?? "(no response)"} ${lastResp?.body ?? ""}",
    );
  }
}

String _asString(dynamic v) => (v ?? "").toString().trim();

String _firstNonEmpty(List<String> vals) {
  for (final s in vals) {
    if (s.trim().isNotEmpty) return s.trim();
  }
  return "";
}

String _extractYoutubeId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return "";

  if (uri.host.contains("youtu.be")) {
    if (uri.pathSegments.isNotEmpty) return uri.pathSegments.first;
  }

  final v = uri.queryParameters["v"];
  if (v != null && v.isNotEmpty) return v;

  // Sometimes embed URLs: /embed/<id>
  final segs = uri.pathSegments;
  final embedIndex = segs.indexOf("embed");
  if (embedIndex != -1 && embedIndex + 1 < segs.length) {
    return segs[embedIndex + 1];
  }

  return "";
}
