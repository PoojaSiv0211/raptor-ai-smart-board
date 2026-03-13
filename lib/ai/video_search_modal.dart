import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../settings/settings_controller.dart';
import 'tools/video_search_service.dart';

Future<void> showVideoSearchModal(BuildContext context) async {
  // Always show on root navigator
  final rootCtx = Navigator.of(context, rootNavigator: true).context;

  await showDialog(
    context: rootCtx,
    barrierDismissible: true,
    builder: (_) => const _VideoSearchDialog(),
  );
}

class _VideoSearchDialog extends StatefulWidget {
  const _VideoSearchDialog();

  @override
  State<_VideoSearchDialog> createState() => _VideoSearchDialogState();
}

class _VideoSearchDialogState extends State<_VideoSearchDialog> {
  final _controller = TextEditingController(text: "linear regression");
  final _service = VideoSearchService();

  bool _loading = false;
  String? _error;
  List<VideoSearchResult> _results = [];

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final count = context
          .read<SettingsController>()
          .settings
          .imageResultCount;

      final r = await _service.search(q, maxResults: count);
      setState(() => _results = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _copy(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: u));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Copied link")));
  }

  Future<void> _play(VideoSearchResult v) async {
    final id = v.videoId.trim();
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No playable YouTube ID.")));
      return;
    }

    final rootCtx = Navigator.of(context, rootNavigator: true).context;

    final embedUrl =
        "https://www.youtube.com/embed/$id?autoplay=1&controls=1&rel=0&modestbranding=1";

    final web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(embedUrl));

    await showDialog(
      context: rootCtx,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          content: SizedBox(
            width: 900,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: WebViewWidget(controller: web),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Video Search"),
      content: SizedBox(
        width: 900,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: "Search videos",
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
            const SizedBox(height: 14),

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

            if (_results.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 420,
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 18),
                  itemBuilder: (_, i) {
                    final v = _results[i];

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: v.thumbnailUrl.trim().isEmpty
                            ? Container(
                                width: 120,
                                height: 68,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image),
                              )
                            : Image.network(
                                v.thumbnailUrl,
                                width: 120,
                                height: 68,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 120,
                                  height: 68,
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                      ),
                      title: Text(
                        v.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        v.channelTitle.isEmpty ? "YouTube" : v.channelTitle,
                      ),
                      onTap: () => _play(v),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copy(v.url),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Tip: Click a video to play. Use copy icon to copy link.",
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
