import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../file_system/file_controller.dart';

Future<void> showUploadModal(BuildContext context, FileController controller) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UploadDialog(ctrl: controller),
  );
}

class _UploadDialog extends StatefulWidget {
  const _UploadDialog({required this.ctrl});
  final FileController ctrl;

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  bool dragging = false;

  Future<void> _browse() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ["png", "jpg", "jpeg", "gif", "csv", "json", "pdf"],
      withData: false,
    );
    if (res == null) return;

    final files = res.paths.whereType<String>().map((p) => File(p)).toList();
    if (files.isEmpty) return;

    await widget.ctrl.importFiles(files);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.ctrl,
      builder: (_, __) {
        return AlertDialog(
          title: const Text("Upload Files"),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropTarget(
                  onDragEntered: (_) => setState(() => dragging = true),
                  onDragExited: (_) => setState(() => dragging = false),
                  onDragDone: (detail) async {
                    final files = detail.files
                        .map((x) => File(x.path))
                        .toList();
                    await widget.ctrl.importFiles(files);
                    setState(() => dragging = false);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: dragging ? Colors.red : Colors.black12,
                        width: 2,
                      ),
                      color: const Color(0xFFF7F5FA),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_upload,
                          size: 40,
                          color: dragging ? Colors.red : Colors.black54,
                        ),
                        const SizedBox(height: 10),
                        const Text("Drag & Drop files here (Desktop)"),
                        const SizedBox(height: 6),
                        const Text(
                          "PNG/JPG/GIF, CSV, JSON, PDF — Max 10MB each",
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: widget.ctrl.isUploading ? null : _browse,
                          icon: const Icon(Icons.folder_open),
                          label: const Text("Browse Files"),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (widget.ctrl.isUploading) ...[
                  LinearProgressIndicator(value: widget.ctrl.uploadProgress),
                  const SizedBox(height: 8),
                  Text(
                    "Uploading... ${(widget.ctrl.uploadProgress * 100).toStringAsFixed(0)}%",
                  ),
                ],

                if (widget.ctrl.uploadError != null) ...[
                  const SizedBox(height: 8),
                  _ErrorBox(msg: widget.ctrl.uploadError!),
                ],

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Repository: ${widget.ctrl.repo.length} files",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: widget.ctrl.isUploading
                  ? null
                  : () => Navigator.pop(context),
              child: const Text("Close"),
            ),
            if (widget.ctrl.repo.isNotEmpty)
              TextButton(
                onPressed: widget.ctrl.isUploading
                    ? null
                    : () {
                        // keep files, just exit
                        Navigator.pop(context);
                      },
                child: const Text("Done"),
              ),
          ],
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Text(msg),
    );
  }
}
