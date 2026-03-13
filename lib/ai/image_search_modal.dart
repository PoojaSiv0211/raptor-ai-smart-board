import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'ai_config.dart';
import '../settings/settings_controller.dart';
import '../settings/app_settings.dart';

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

  factory ImageSearchResult.fromJson(Map<String, dynamic> m) {
    return ImageSearchResult(
      title: (m["title"] ?? "Image").toString(),
      imageUrl: (m["imageUrl"] ?? "").toString(),
      thumbnailUrl: (m["thumbnailUrl"] ?? "").toString(),
      sourceUrl: (m["sourceUrl"] ?? "").toString(),
    );
  }
}

Future<void> showImageSearchModal(
  BuildContext context, {
  void Function(String imageUrl)? onInsertToBoard,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ImageSearchDialog(onInsertToBoard: onInsertToBoard),
  );
}

class _ImageSearchDialog extends StatefulWidget {
  const _ImageSearchDialog({this.onInsertToBoard});

  final void Function(String imageUrl)? onInsertToBoard;

  @override
  State<_ImageSearchDialog> createState() => _ImageSearchDialogState();
}

class _ImageSearchDialogState extends State<_ImageSearchDialog> {
  final _controller = TextEditingController();

  bool _loading = false;
  String? _error;
  List<ImageSearchResult> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _proxied(String rawUrl) {
    final u = rawUrl.trim();
    if (u.isEmpty) return rawUrl;
    return "${AIConfig.baseUrl}/proxy_image?url=${Uri.encodeComponent(u)}";
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    final s = context.read<SettingsController>().settings;
    final maxResults = s.imageResultCount.clamp(1, 50);

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final uri = Uri.parse("${AIConfig.baseUrl}/search_images").replace(
        queryParameters: {"q": q, "max_results": maxResults.toString()},
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
          "Image search failed: ${response.statusCode} ${response.body}",
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data["items"] as List?) ?? const [];

      final parsed = items
          .map(
            (e) =>
                ImageSearchResult.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .where(
            (x) =>
                x.imageUrl.trim().isNotEmpty ||
                x.thumbnailUrl.trim().isNotEmpty,
          )
          .toList();

      if (!mounted) return;
      setState(() => _results = parsed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Copied link")));
  }

  void _insertOrFullscreen(ImageSearchResult item) {
    final s = context.read<SettingsController>().settings;

    // Always insert with the ORIGINAL image URL (not proxied)
    final rawFull = item.imageUrl.isNotEmpty
        ? item.imageUrl
        : item.thumbnailUrl;

    final canInsert = widget.onInsertToBoard != null;
    final shouldAutoInsert = s.imageAutoInsert && canInsert;

    if (shouldAutoInsert) {
      widget.onInsertToBoard?.call(rawFull);
      Navigator.pop(context); // close search modal after insert
      return;
    }

    _openFullscreen(item);
  }

  void _openFullscreen(ImageSearchResult item) {
    final rawFull = item.imageUrl.isNotEmpty
        ? item.imageUrl
        : item.thumbnailUrl;
    final fullUrl = _proxied(rawFull);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  fullUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                      "Failed to load image",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                children: [
                  if (widget.onInsertToBoard != null)
                    IconButton(
                      tooltip: "Insert to board",
                      onPressed: () {
                        widget.onInsertToBoard?.call(rawFull);
                        Navigator.pop(context); // close fullscreen
                        Navigator.pop(this.context); // close modal
                      },
                      icon: const Icon(
                        Icons.add_box_outlined,
                        color: Colors.white,
                      ),
                    ),
                  IconButton(
                    tooltip: "Copy image URL",
                    onPressed: () => _copy(rawFull),
                    icon: const Icon(Icons.copy, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: "Close",
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image_outlined, size: 28)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;

    final w = MediaQuery.of(context).size.width;
    final crossAxisCount = w >= 1300
        ? 6
        : w >= 1000
        ? 5
        : w >= 800
        ? 4
        : 3;

    return AlertDialog(
      title: const Text("Image Search"),
      content: SizedBox(
        width: 980,
        height: 620,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: "Search images...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Search"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_results.isEmpty && !_loading && _error == null)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Enter a query and press Search."),
              ),
            const SizedBox(height: 8),

            Expanded(
              child: _results.isEmpty
                  ? const SizedBox.shrink()
                  : GridView.builder(
                      padding: const EdgeInsets.only(top: 6),
                      itemCount: _results.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (_, i) {
                        final item = _results[i];

                        final rawThumb =
                            settings.imageQuality == ImageQuality.high
                            ? (item.imageUrl.isNotEmpty
                                  ? item.imageUrl
                                  : item.thumbnailUrl)
                            : (item.thumbnailUrl.isNotEmpty
                                  ? item.thumbnailUrl
                                  : item.imageUrl);

                        final thumbUrl = _proxied(rawThumb);

                        return InkWell(
                          onTap: () => _insertOrFullscreen(item),
                          borderRadius: BorderRadius.circular(12),
                          child: _thumbImage(thumbUrl),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text("Close"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
