import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String API = "http://127.0.0.1:5000";

class FileRepository extends StatefulWidget {
  final VoidCallback? onClose;
  final Function(String url)? onOpenInBoard;

  const FileRepository({super.key, this.onClose, this.onOpenInBoard});

  @override
  State<FileRepository> createState() => _FileRepositoryState();
}

class _FileRepositoryState extends State<FileRepository> {
  List<String> folders = [];
  String activeFolder = "Default";
  List<String> files = [];
  String search = "";
  String newFolderName = "";
  bool loading = false;
  late TextEditingController _folderController;

  @override
  void initState() {
    super.initState();
    _folderController = TextEditingController();
    fetchFolders();
  }

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  Future<void> fetchFolders() async {
    try {
      final res = await http.get(Uri.parse("$API/api/folders"));
      final data = jsonDecode(res.body);
      final list = List<String>.from(data["folders"] ?? [])..sort();

      setState(() {
        folders = list;
        if (!folders.contains(activeFolder)) activeFolder = "Default";
      });

      fetchFiles(activeFolder);
    } catch (_) {
      showToast("Backend not running");
    }
  }

  Future<void> fetchFiles(String folder) async {
    try {
      final res = await http.get(
        Uri.parse("$API/api/files?folder=${Uri.encodeComponent(folder)}"),
      );
      final data = jsonDecode(res.body);
      setState(() => files = List<String>.from(data["files"] ?? [])..sort());
    } catch (_) {
      showToast("Failed to load files");
    }
  }

  void showToast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> createFolder() async {
    final name = _folderController.text.trim();
    if (name.isEmpty) return showToast("Folder name empty");

    try {
      final res = await http.post(
        Uri.parse("$API/api/folders"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name}),
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        showToast("Create failed");
        return;
      }

      _folderController.clear();
      fetchFolders();
    } catch (_) {
      showToast("Backend not running");
    }
  }

  Future<void> deleteFile(String filename) async {
    try {
      await http.post(
        Uri.parse("$API/api/delete"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "folder": activeFolder,
          "filename": filename,
        }),
      );
      fetchFiles(activeFolder);
    } catch (_) {
      showToast("Delete failed");
    }
  }

  List<String> get filteredFiles {
    final q = search.toLowerCase();
    if (q.isEmpty) return files;
    return files.where((f) => f.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("File Repository"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onClose ?? () => Navigator.pop(context),
        ),
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            color: Colors.grey.shade900,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    "Folders",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: folders
                        .map(
                          (f) => ListTile(
                            title: Text(
                              f,
                              style: TextStyle(
                                color: f == activeFolder
                                    ? Colors.blue
                                    : Colors.white,
                                fontWeight: f == activeFolder
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: f == activeFolder,
                            selectedTileColor: Colors.blue.withOpacity(0.1),
                            onTap: () {
                              setState(() => activeFolder = f);
                              fetchFiles(f);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          // Files panel
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: "Search files...",
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (v) => setState(() => search = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: "New folder name",
                              prefixIcon: Icon(Icons.folder),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            controller: _folderController,
                            onChanged: (v) => setState(() => newFolderName = v),
                            onSubmitted: (_) => createFolder(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: createFolder,
                          icon: const Icon(Icons.add),
                          label: const Text("Create"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : filteredFiles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.folder_open,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      search.isNotEmpty
                                          ? "No files match your search"
                                          : "No files in this folder",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.8,
                                ),
                                itemCount: filteredFiles.length,
                                itemBuilder: (context, index) {
                                  final file = filteredFiles[index];
                                  return GestureDetector(
                                    onDoubleTap: () {
                                      final url = "$API/api/open/$activeFolder/$file";
                                      widget.onOpenInBoard?.call(url);
                                      Navigator.of(context).pop();
                                    },
                                    child: Card(
                                      elevation: 2,
                                      color: Colors.white,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              child: Icon(
                                                _getFileIcon(file),
                                                color: _getFileColor(file),
                                                size: 48,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    file,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed: () => _confirmDelete(file),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'txt':
        return Colors.grey;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _confirmDelete(String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete File"),
        content: Text("Are you sure you want to delete '$filename'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              deleteFile(filename);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}