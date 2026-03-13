import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'canvas_manager.dart';
import 'crop_tool.dart';
import 'move_tool.dart';
import 'spotlight_overlay.dart';
import 'drawing_integration.dart';
import 'crop_preview_painter.dart';
import 'eraser_cursor.dart';
import 'drawables.dart';
import '../board_command.dart';

class CanvasBoardWidget extends StatefulWidget {
  const CanvasBoardWidget({
    super.key,
    required this.vm,
    this.activeTool,
    this.selectedShape = ShapeType.rectangle,
    this.onToolChange,
    this.onDrawingIntegrationReady,
  });

  final CanvasManager vm;
  final BoardCommand? activeTool;
  final ShapeType selectedShape;
  final void Function(BoardCommand?)? onToolChange;
  final void Function(DrawingIntegration)? onDrawingIntegrationReady;

  @override
  State<CanvasBoardWidget> createState() => _CanvasBoardWidgetState();
}

class _CanvasBoardWidgetState extends State<CanvasBoardWidget> {
  late final CropToolController cropCtrl = CropToolController(widget.vm);
  late final MoveToolController moveCtrl = MoveToolController(widget.vm);
  late final DrawingIntegration drawingIntegration = DrawingIntegration(
    widget.vm,
  );

  Size _size = Size.zero;
  Offset _mousePosition = Offset.zero;
  bool _isMouseInCanvas = false;

  @override
  void initState() {
    super.initState();
    drawingIntegration.addListener(_onDrawingUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDrawingIntegrationReady?.call(drawingIntegration);
    });
  }

  @override
  void dispose() {
    drawingIntegration.removeListener(_onDrawingUpdate);
    drawingIntegration.dispose();
    super.dispose();
  }

  void _onDrawingUpdate() {
    setState(() {});
  }

  @override
  void didUpdateWidget(CanvasBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTool != oldWidget.activeTool) {
      drawingIntegration.setTool(widget.activeTool ?? BoardCommand.pen);
    }
    if (widget.selectedShape != oldWidget.selectedShape) {
      drawingIntegration.setSelectedShape(widget.selectedShape);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        _size = Size(c.maxWidth, c.maxHeight);

        return AnimatedBuilder(
          animation: widget.vm,
          builder: (_, __) {
            widget.vm.ensureCache(_size);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) {
                final p = d.localPosition;

                if (widget.vm.mode == EditMode.crop) {
                  cropCtrl.onStart(p);
                } else if (widget.vm.mode == EditMode.move) {
                  moveCtrl.onStart(p);
                } else if (widget.vm.mode == EditMode.spotlight) {
                  widget.vm.startSpotlight(p);
                } else if (widget.vm.mode == EditMode.circleSearch) {
                  widget.vm.startCircleSearchLasso(p);
                } else if (widget.vm.mode == EditMode.draw) {
                  drawingIntegration.onPanStart(p);
                }
              },
              onPanUpdate: (d) {
                final p = d.localPosition;

                if (widget.vm.mode == EditMode.crop) {
                  cropCtrl.onUpdate(p);
                } else if (widget.vm.mode == EditMode.move) {
                  moveCtrl.onUpdate(p);
                } else if (widget.vm.mode == EditMode.spotlight) {
                  widget.vm.updateSpotlight(p);
                } else if (widget.vm.mode == EditMode.circleSearch) {
                  widget.vm.updateCircleSearchLasso(p);
                } else if (widget.vm.mode == EditMode.draw) {
                  drawingIntegration.onPanUpdate(p);
                }
              },
              onPanEnd: (_) {
                if (widget.vm.mode == EditMode.crop) {
                  cropCtrl.onEnd();
                } else if (widget.vm.mode == EditMode.move) {
                  moveCtrl.onEnd();
                } else if (widget.vm.mode == EditMode.spotlight) {
                  widget.vm.stopSpotlight();
                } else if (widget.vm.mode == EditMode.draw) {
                  drawingIntegration.onPanEnd();
                }
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _isMouseInCanvas = true),
                onExit: (_) => setState(() => _isMouseInCanvas = false),
                onHover: (event) =>
                    setState(() => _mousePosition = event.localPosition),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _BasePainter(widget.vm.cachedPicture),
                        ),
                      ),
                    ),

                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _PreviewPainter(
                            drawingIntegration.previewItem,
                          ),
                        ),
                      ),
                    ),

                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: CropPreviewPainter(
                            preview: widget.vm.cropPreviewRect,
                            existingCrop: widget.vm.cropRect,
                          ),
                        ),
                      ),
                    ),

                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CircleSearchPainter(
                            widget.vm.circleSearchPoints,
                            enabled: widget.vm.mode == EditMode.circleSearch,
                          ),
                        ),
                      ),
                    ),

                    SpotlightOverlay(
                      enabled: widget.vm.spotlightEnabled,
                      position: widget.vm.spotlightPosition,
                      radius: widget.vm.spotlightRadius,
                    ),

                    EraserCursor(
                      position: _mousePosition,
                      radius: drawingIntegration.eraserRadius,
                      isVisible:
                          _isMouseInCanvas &&
                          widget.activeTool == BoardCommand.eraser &&
                          widget.vm.mode == EditMode.draw,
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
  const _BasePainter(this.picture);

  final ui.Picture? picture;

  @override
  void paint(Canvas canvas, Size size) {
    if (picture == null) return;
    canvas.drawPicture(picture!);
  }

  @override
  bool shouldRepaint(covariant _BasePainter oldDelegate) =>
      oldDelegate.picture != picture;
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(this.previewItem);

  final DrawableItem? previewItem;

  @override
  void paint(Canvas canvas, Size size) {
    previewItem?.draw(canvas);
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) =>
      oldDelegate.previewItem != previewItem;
}

class _CircleSearchPainter extends CustomPainter {
  const _CircleSearchPainter(this.points, {required this.enabled});

  final List<Offset> points;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled || points.length < 2) return;

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);

    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    final Paint glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint strokePaint = Paint()
      ..color = const Color(0xFF7C4DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CircleSearchPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.enabled != enabled;
  }
}
