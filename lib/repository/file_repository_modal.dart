import 'package:flutter/material.dart';

import '../file_system/file_controller.dart';
import '../file_system/file_models.dart';

Future<void> showFileRepositoryModal(
  BuildContext context,
  FileController controller,
) {
  return showDialog(
    context: context,
    builder: (_) => _FileRepoDialog(ctrl: controller),
  );
}

class _FileRepoDialog extends StatefulWidget {
  const _FileRepoDialog({required this.ctrl});
  final FileController ctrl;

  @override
  State<_FileRepoDialog> createState() => _FileRepoDialogState();
}

class _FileRepoDialogState extends State<_FileRepoDialog> {
  BoardFile? selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.ctrl,
      builder: (_, __) {
        final files = widget.ctrl.repo;

        return AlertDialog(
          title: const Text("File Repository"),
          content: SizedBox(
            width: 720,
            height: 420,
            child: Row(
              children: [
                // Left list
                Expanded(
                  flex: 4,
                  child: ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final f = files[i];
                      final isSel = selected?.id == f.id;

                      return ListTile(
                        selected: isSel,
                        leading: _FileIcon(f.type),
                        title: Text(
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(f.type.name),
                        onTap: () => setState(() => selected = f),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => widget.ctrl.deleteFile(f),
                        ),
                      );
                    },
                  ),
                ),

                const VerticalDivider(width: 1),

                // Right preview
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFFF7F5FA),
                    child: selected == null
                        ? const Center(child: Text("Select a file to preview"))
                        : _PreviewPane(ctrl: widget.ctrl, file: selected!),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () {
                      widget.ctrl.setPending(selected!);
                      Navigator.pop(context);
                    },
              child: const Text("Place on Board"),
            ),
          ],
        );
      },
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon(this.type);
  final BoardFileType type;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case BoardFileType.image:
        return const Icon(Icons.image);
      case BoardFileType.csv:
        return const Icon(Icons.table_chart);
      case BoardFileType.json:
        return const Icon(Icons.data_object);
      case BoardFileType.pdf:
        return const Icon(Icons.picture_as_pdf);
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.ctrl, required this.file});

  final FileController ctrl;
  final BoardFile file;

  @override
  Widget build(BuildContext context) {
    if (file.type == BoardFileType.image && file.thumbnailPng != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: Image.memory(file.thumbnailPng!, fit: BoxFit.contain),
          ),
        ],
      );
    }

    if (file.type == BoardFileType.csv || file.type == BoardFileType.json) {
      return FutureBuilder<String>(
        future: ctrl.readAsPreviewText(file),
        builder: (_, snap) {
          final text = snap.data ?? "Loading preview...";
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(child: SelectableText(text)),
              ),
            ],
          );
        },
      );
    }

    if (file.type == BoardFileType.pdf) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("PDF preview: open it inside the board overlay"),
        ],
      );
    }

    return Text("No preview available for ${file.type.name}");
  }
}
