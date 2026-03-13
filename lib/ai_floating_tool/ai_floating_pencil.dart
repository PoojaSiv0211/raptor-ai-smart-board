import 'dart:math';
import 'package:flutter/material.dart';
import '../board_command.dart';

class AIFloatingPencil extends StatefulWidget {
  const AIFloatingPencil({super.key, required this.onCommand});
  final void Function(BoardCommand command) onCommand;

  @override
  State<AIFloatingPencil> createState() => _AIFloatingPencilState();
}

class _AIFloatingPencilState extends State<AIFloatingPencil> {
  bool _open = false;

  double right = 16;
  double bottom = 16;

  final GlobalKey _fabKey = GlobalKey();
  OverlayEntry? _entry;

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  void _run(BoardCommand command) {
    debugPrint("AIFloatingPencil: pressed $command");
    setState(() => _open = false);
    _removeOverlay();
    widget.onCommand(command);
  }

  void _drag(DragUpdateDetails d) {
    setState(() {
      right -= d.delta.dx;
      bottom -= d.delta.dy;
    });

    if (_open) {
      _removeOverlay();
      _showOverlay();
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context, rootOverlay: true);

    final box = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final fabPos = box.localToGlobal(Offset.zero);
    final fabSize = box.size;

    final center = Offset(
      fabPos.dx + fabSize.width / 2,
      fabPos.dy + fabSize.height / 2,
    );

    const radius = 110.0;
    final items = [
      _OverlayItem(Icons.menu_book, "Lesson", BoardCommand.aiLesson),
      _OverlayItem(Icons.quiz, "Quiz", BoardCommand.aiQuiz),
      _OverlayItem(Icons.image_search, "Image", BoardCommand.aiImageSearch),
      _OverlayItem(Icons.video_library, "Video", BoardCommand.aiVideoSearch),
    ];

    // neat arc (upper-left)
    final angles = <double>[215, 245, 275, 305];

    _entry = OverlayEntry(
      builder: (overlayCtx) {
        return Stack(
          children: [
            // tap outside to close
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() => _open = false);
                  _removeOverlay();
                },
              ),
            ),

            // buttons
            for (int i = 0; i < items.length; i++)
              Positioned(
                left: center.dx + radius * cos(angles[i] * pi / 180) - 22,
                top: center.dy + radius * sin(angles[i] * pi / 180) - 22,
                child: Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: items[i].label,
                    child: FloatingActionButton(
                      heroTag: "overlay_${items[i].label}",
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      onPressed: () => _run(items[i].command),
                      child: Icon(items[i].icon),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Drag grip
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _drag,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.drag_indicator, size: 18),
            ),
          ),

          // Main button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _drag,
            child: FloatingActionButton(
              key: _fabKey,
              heroTag: "mainAI",
              backgroundColor: Colors.deepPurple,
              onPressed: _toggle,
              child: Icon(_open ? Icons.close : Icons.auto_fix_high),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayItem {
  final IconData icon;
  final String label;
  final BoardCommand command;
  _OverlayItem(this.icon, this.label, this.command);
}
