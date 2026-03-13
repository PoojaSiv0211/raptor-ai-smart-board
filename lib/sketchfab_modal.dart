import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

const String SKETCHFAB_TOKEN = "28835ba9048f4fd1a43e72e66df4f121";

class SketchfabModal extends StatefulWidget {
  const SketchfabModal({super.key});

  @override
  State<SketchfabModal> createState() => _SketchfabModalState();
}

class _SketchfabModalState extends State<SketchfabModal> {
  final TextEditingController controller =
      TextEditingController(text: "plant cell");
  List models = [];
  Map? selected;
  bool loading = false;
  String error = "";

  @override
  void initState() {
    super.initState();
    searchModels("plant cell");
  }

  Future<void> searchModels(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      loading = true;
      error = "";
      models = [];
      selected = null;
    });

    try {
      final url =
          "https://api.sketchfab.com/v3/search?type=models&q=${Uri.encodeComponent(query)}&count=24";
      final res = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Token $SKETCHFAB_TOKEN"},
      );

      if (res.statusCode != 200) {
        throw Exception("API error: ${res.statusCode}");
      }

      final data = jsonDecode(res.body);
      setState(() {
        models = data["results"] ?? [];
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() => loading = false);
    }
  }

  String getThumb(Map m) {
    final imgs = m["thumbnails"]?["images"] ?? [];
    if (imgs.isEmpty) return "";
    for (var img in imgs) {
      if ((img["width"] ?? 0) >= 400) return img["url"];
    }
    return imgs.last["url"];
  }

  String embedUrl(String uid) {
    return "https://sketchfab.com/models/$uid/embed?autostart=1&ui_infos=0&ui_watermark=0&ui_help=0";
  }

  Widget buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: models.length,
      itemBuilder: (_, i) {
        final m = models[i];
        final thumb = getThumb(m);
        return GestureDetector(
          onTap: () => setState(() => selected = m),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected?["uid"] == m["uid"]
                    ? Colors.red
                    : Colors.grey.shade300,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Column(
              children: [
                Expanded(
                  child: thumb.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                          child: Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : const Center(child: Text("No Preview")),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    m["name"] ?? "Untitled",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildViewer() {
    final uid = selected!["uid"];
    final embedUrlString = embedUrl(uid);
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: kIsWeb 
          ? _buildWebViewer(embedUrlString)
          : _buildMobileViewer(embedUrlString),
      ),
    );
  }

  Widget _buildWebViewer(String url) {
    // For web, we'll show a message and provide a link
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.view_in_ar,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            selected!["name"] ?? "3D Model",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "3D model preview is not available in web browser.\nCopy the link below to view in a new tab.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              url,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Copy to clipboard would be ideal, but for now just show the URL
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("URL is displayed above - copy and paste into a new browser tab"),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text("Copy Link"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileViewer(String url) {
    return WebViewWidget(
      controller: WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Sketchfab 3D Models"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          if (selected != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text(
                "Select",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "Search 3D models...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: searchModels,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: loading ? null : () => searchModels(controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(loading ? "..." : "Search"),
                ),
              ],
            ),
          ),
          if (error.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Text(
                error,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          if (loading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 16),
                    Text("Searching 3D models..."),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: selected == null
                  ? buildGrid()
                  : Row(
                      children: [
                        Expanded(flex: 35, child: buildGrid()),
                        const VerticalDivider(width: 1),
                        Expanded(flex: 65, child: buildViewer()),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}