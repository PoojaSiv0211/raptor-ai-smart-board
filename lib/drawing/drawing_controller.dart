import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/stroke_model.dart';
import 'models/shape_model.dart';
import 'models/table_model.dart';
import 'models/text_model.dart';

import 'tools/drawing_tool.dart';
import 'tools/pen_tool.dart';
import 'tools/pencil_tool.dart';
import 'tools/dot_pen_tool.dart';
import 'tools/eraser_tool.dart';
import 'tools/shape_tools.dart';
import 'tools/table_tool.dart';
import 'tools/formula_tool.dart';

/// A committed thing that can be drawn into the base layer cache.
abstract class DrawableAction {
  void draw(Canvas canvas, Size size);
}

/// ---------- ACTIONS ----------
class StrokeAction implements DrawableAction {
  StrokeAction(this.stroke);

  final StrokeModel stroke;

  @override
  void draw(Canvas canvas, Size size) {
    final points = stroke.points;
    if (points.length < 2) return;

    final isEraser = stroke.kind == StrokeKind.eraser;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    if (isEraser) {
      // BlendMode.clear requires a layer to punch through.
      canvas.saveLayer(Offset.zero & size, Paint());
      paint.blendMode = BlendMode.clear;
      paint.color = const Color(0x00000000);
    } else {
      paint.color = stroke.color.withOpacity(stroke.opacity);
    }

    if (stroke.kind == StrokeKind.dot) {
      _drawDots(canvas, paint, points, spacing: stroke.strokeWidth * 2.2);
    } else if (stroke.kind == StrokeKind.pencil) {
      _drawPencil(canvas, paint, points);
    } else {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (isEraser) canvas.restore();
  }

  void _drawDots(
    Canvas canvas,
    Paint paint,
    List<Offset> pts, {
    required double spacing,
  }) {
    if (pts.length < 2) return;
    double distCarry = 0;
    Offset prev = pts.first;

    for (int i = 1; i < pts.length; i++) {
      final cur = pts[i];
      final seg = (cur - prev);
      final segLen = seg.distance;

      if (segLen == 0) continue;

      double d = spacing - distCarry;
      while (d <= segLen) {
        final t = d / segLen;
        final p = Offset(prev.dx + seg.dx * t, prev.dy + seg.dy * t);
        canvas.drawCircle(
          p,
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        d += spacing;
      }

      distCarry = (segLen + distCarry) % spacing;
      prev = cur;
    }
  }

  void _drawPencil(Canvas canvas, Paint paint, List<Offset> pts) {
    // Pencil feel: slightly transparent + light blur + micro “grain”
    paint
      ..color = paint.color.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);

    // Main path
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);

    // Grain: short micro strokes along the path (cheap texture)
    final grainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = paint.color.withOpacity(0.18);

    for (int i = 2; i < pts.length; i += 3) {
      final a = pts[i - 1];
      final b = pts[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      canvas.drawLine(mid, mid + const Offset(0.8, -0.6), grainPaint);
    }
  }
}

class ShapeAction implements DrawableAction {
  ShapeAction(this.shape);
  final ShapeModel shape;

  @override
  void draw(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = shape.strokeWidth
      ..color = shape.color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    ShapePainter.drawShape(canvas, paint, shape);
  }
}

class TableAction implements DrawableAction {
  TableAction(this.table);
  final TableModel table;

  @override
  void draw(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = table.strokeWidth
      ..color = table.color
      ..isAntiAlias = true;

    final rect = table.rect;
    // Outer border
    canvas.drawRect(rect, paint);

    // Vertical lines
    for (int c = 1; c < table.cols; c++) {
      final x = rect.left + c * table.cellWidth;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }

    // Horizontal lines
    for (int r = 1; r < table.rows; r++) {
      final y = rect.top + r * table.cellHeight;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }
}

/// NOTE: Text is drawn in overlay (widgets), but we still keep it for history/state.
class TextAddAction implements DrawableAction {
  TextAddAction(this.text);
  final TextModel text;

  @override
  void draw(Canvas canvas, Size size) {
    // No-op: overlay widget draws it. Action is for history only.
  }
}

/// ---------- CONTROLLER ----------
enum ToolType { pen, pencil, dotPen, eraser, shape, table, formula }

class DrawingController extends ChangeNotifier {
  DrawingController() {
    _setToolInternal(ToolType.pen);
  }

  // Public state
  Color color = Colors.black;
  double strokeWidth = 4;

  ToolType activeToolType = ToolType.pen;
  DrawingTool get activeTool => _activeTool;

  ShapeType activeShapeType = ShapeType.rectangle;

  // Preview objects
  DrawableAction? previewAction; // drawn only on preview layer

  // Overlay text
  final List<TextModel> texts = [];

  // History (limit 50)
  final List<DrawableAction> _actions = [];
  final ListQueue<List<DrawableAction>> _undoStack = ListQueue();
  final ListQueue<List<DrawableAction>> _redoStack = ListQueue();
  static const int historyLimit = 50;

  // Performance cache (base layer)
  ui.Picture? _cachedBasePicture;
  Size? _cachedSize;
  bool _cacheDirty = true;

  late DrawingTool _activeTool;

  // --- Tool switching ---
  void setTool(ToolType type) {
    if (activeToolType == type) return;
    _setToolInternal(type);
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    notifyListeners();
  }

  void setStrokeWidth(double w) {
    strokeWidth = w.clamp(1, 40);
    notifyListeners();
  }

  void setActiveShape(ShapeType t) {
    activeShapeType = t;
    if (activeToolType == ToolType.shape) notifyListeners();
  }

  // --- Input events from canvas_widget ---
  void pointerDown(Offset p) => _activeTool.onStart(p);
  void pointerMove(Offset p) => _activeTool.onUpdate(p);
  void pointerUp() => _activeTool.onEnd();

  // --- Commit actions ---
  void commitAction(DrawableAction action) {
    _actions.add(action);

    _pushUndoSnapshot();
    _redoStack.clear();

    _cacheDirty = true;
    previewAction = null;
    notifyListeners();
  }

  void setPreview(DrawableAction? action) {
    previewAction = action;
    // only preview changed: repaint preview layer
    notifyListeners();
  }

  // --- Cache painting ---
  ui.Picture? get cachedBasePicture => _cachedBasePicture;

  void ensureBaseCache(Size size) {
    if (!_cacheDirty && _cachedBasePicture != null && _cachedSize == size) {
      return;
    }

    _cachedSize = size;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Whiteboard background (transparent because your container already has bg)
    // Draw all committed actions
    for (final a in _actions) {
      a.draw(canvas, size);
    }

    _cachedBasePicture = recorder.endRecording();
    _cacheDirty = false;
  }

  // --- Undo/Redo ---
  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.addLast(List<DrawableAction>.from(_actions));
    final prev = _undoStack.removeLast();
    _actions
      ..clear()
      ..addAll(prev);
    _cacheDirty = true;
    previewAction = null;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.addLast(List<DrawableAction>.from(_actions));
    final next = _redoStack.removeLast();
    _actions
      ..clear()
      ..addAll(next);
    _cacheDirty = true;
    previewAction = null;
    notifyListeners();
  }

  void clear() {
    _undoStack.addLast(List<DrawableAction>.from(_actions));
    _redoStack.clear();
    _actions.clear();
    texts.clear();
    _cacheDirty = true;
    previewAction = null;
    notifyListeners();
  }

  void addText(TextModel t) {
    texts.add(t);
    _pushUndoSnapshot(); // snapshot includes “texts” logically via state; action is stored too
    _redoStack.clear();
    _actions.add(TextAddAction(t));
    notifyListeners();
  }

  void moveText(String id, Offset newPos) {
    final idx = texts.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    texts[idx] = texts[idx].copyWith(position: newPos);
    notifyListeners();
  }

  // --- Internals ---
  void _setToolInternal(ToolType type) {
    activeToolType = type;

    switch (type) {
      case ToolType.pen:
        _activeTool = PenTool(this);
        break;
      case ToolType.pencil:
        _activeTool = PencilTool(this);
        break;
      case ToolType.dotPen:
        _activeTool = DotPenTool(this);
        break;
      case ToolType.eraser:
        _activeTool = EraserTool(this);
        break;
      case ToolType.shape:
        _activeTool = ShapeTool(this);
        break;
      case ToolType.table:
        _activeTool = TableTool(this);
        break;
      case ToolType.formula:
        _activeTool = FormulaTool(this);
        break;
    }

    previewAction = null;
  }

  void _pushUndoSnapshot() {
    _undoStack.addLast(List<DrawableAction>.from(_actions));
    if (_undoStack.length > historyLimit) {
      _undoStack.removeFirst();
    }
    if (_redoStack.length > historyLimit) {
      _redoStack.removeFirst();
    }
  }
}
