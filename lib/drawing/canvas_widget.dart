import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'drawing_controller.dart';
import 'tools/formula_tool.dart';

class DrawingCanvasWidget extends StatefulWidget {
  const DrawingCanvasWidget({super.key, required this.controller});

  final DrawingController controller;

  @override
  State<DrawingCanvasWidget> createState() => _DrawingCanvasWidgetState();
}

class _DrawingCanvasWidgetState extends State<DrawingCanvasWidget> {
  Size _lastSize = Size.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastSize = Size(constraints.maxWidth, constraints.maxHeight);

        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            // Update cached base picture only when needed
            widget.controller.ensureBaseCache(_lastSize);

            return RepaintBoundary(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) =>
                    widget.controller.pointerDown(d.localPosition),
                onPanUpdate: (d) =>
                    widget.controller.pointerMove(d.localPosition),
                onPanEnd: (_) => widget.controller.pointerUp(),
                child: Stack(
                  children: [
                    // Base layer (cached picture)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BasePainter(
                          widget.controller.cachedBasePicture,
                        ),
                      ),
                    ),

                    // Preview layer (only current stroke/shape/table)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _PreviewPainter(
                            widget.controller.previewAction,
                          ),
                        ),
                      ),
                    ),

                    // UI overlay layer: draggable texts
                    ...widget.controller.texts.map((t) {
                      return Positioned(
                        left: t.position.dx,
                        top: t.position.dy,
                        child: GestureDetector(
                          onPanUpdate: (d) => widget.controller.moveText(
                            t.id,
                            t.position + d.delta,
                          ),
                          child: Text(
                            t.text,
                            style: TextStyle(
                              fontSize: t.fontSize,
                              color: t.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),

                    // Formula floating panel (only when formula tool active)
                    if (widget.controller.activeToolType == ToolType.formula)
                      Positioned(
                        right: 18,
                        top: 18,
                        child: FormulaPanel(controller: widget.controller),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BasePainter extends CustomPainter {
  _BasePainter(this.picture);

  final ui.Picture? picture;

  @override
  void paint(Canvas canvas, Size size) {
    if (picture == null) return;
    canvas.drawPicture(picture!);
  }

  @override
  bool shouldRepaint(covariant _BasePainter oldDelegate) {
    return oldDelegate.picture != picture;
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.preview);

  final DrawableAction? preview;

  @override
  void paint(Canvas canvas, Size size) {
    preview?.draw(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) {
    return oldDelegate.preview != preview;
  }
}
