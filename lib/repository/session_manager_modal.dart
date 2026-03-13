import 'package:flutter/material.dart';

import '../storage/session_storage.dart';

Future<void> showSessionManagerModal(
  BuildContext context, {
  required Future<List<SessionMeta>> Function() loader,
  required Future<void> Function(String id) onLoad,
  required Future<void> Function(String id) onDelete,
}) {
  return showDialog(
    context: context,
    builder: (_) =>
        _SessionDialog(loader: loader, onLoad: onLoad, onDelete: onDelete),
  );
}

class _SessionDialog extends StatefulWidget {
  const _SessionDialog({
    required this.loader,
    required this.onLoad,
    required this.onDelete,
  });

  final Future<List<SessionMeta>> Function() loader;
  final Future<void> Function(String id) onLoad;
  final Future<void> Function(String id) onDelete;

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  late Future<List<SessionMeta>> future;

  @override
  void initState() {
    super.initState();
    future = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Sessions"),
      content: SizedBox(
        width: 720,
        height: 420,
        child: FutureBuilder<List<SessionMeta>>(
          future: future,
          builder: (_, snap) {
            final items = snap.data ?? [];
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return const Center(child: Text("No sessions saved yet."));
            }

            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = items[i];
                final dt = DateTime.fromMillisecondsSinceEpoch(s.timestampMs);

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      s.thumbnailPng,
                      width: 72,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(s.name),
                  subtitle: Text("${dt.toLocal()}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await widget.onLoad(s.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text("Load"),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          await widget.onDelete(s.id);
                          setState(() => future = widget.loader());
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            );
          },
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
