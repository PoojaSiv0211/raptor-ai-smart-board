import 'dart:math';
import 'package:flutter/material.dart';

import 'canvas_manager.dart';
import 'drawables.dart';
import '../board_command.dart';

/// Integration layer that connects drawing tools with the canvas system
class DrawingIntegration extends ChangeNotifier {
  DrawingIntegration(this.canvasManager);

  final CanvasManager canvasManager;

  // Current drawing state
  BoardCommand? _activeTool;
  List<Offset> _currentStroke = [];
  List<Offset> _smoothedStroke = [];
  Offset? _shapeStart;
  Offset? _currentShapeEnd;
  bool _isDrawing = false;
  
  // Shape selection state
  ShapeType _selectedShape = ShapeType.rectangle;
  Color _selectedShapeColor = Colors.black;
  
  // Eraser settings
  double _eraserRadius = 22.0;
  
  // Preview items for real-time feedback
  DrawableItem? _previewItem;

  BoardCommand? get activeTool => _activeTool;
  ShapeType get selectedShape => _selectedShape;
  Color get selectedShapeColor => _selectedShapeColor;
  DrawableItem? get previewItem => _previewItem;
  double get eraserRadius => _eraserRadius;

  void setTool(BoardCommand tool) {
    _activeTool = tool;
    _cancelCurrentDrawing();
    notifyListeners();
  }
  
  void setSelectedShape(ShapeType shape) {
    _selectedShape = shape;
    notifyListeners();
  }
  
  void setSelectedShapeColor(Color color) {
    _selectedShapeColor = color;
    notifyListeners();
  }
  
  void setEraserRadius(double radius) {
    _eraserRadius = radius.clamp(5.0, 50.0);
    notifyListeners();
  }

  void onPanStart(Offset point) {
    if (_activeTool == null) return;

    _isDrawing = true;
    _previewItem = null;
    
    switch (_activeTool!) {
      case BoardCommand.pen:
      case BoardCommand.pencil:
      case BoardCommand.dotPen:
        _currentStroke = [point];
        _smoothedStroke = [point];
        break;
      
      case BoardCommand.eraser:
        canvasManager.eraseAt(point, radius: _eraserRadius);
        break;
      
      case BoardCommand.shapes:
      case BoardCommand.tables:
        _shapeStart = point;
        _currentShapeEnd = point;
        break;
        
      case BoardCommand.formula:
        _showFormulaAt(point);
        break;
        
      default:
        break;
    }
    notifyListeners();
  }

  void onPanUpdate(Offset point) {
    if (!_isDrawing || _activeTool == null) return;

    switch (_activeTool!) {
      case BoardCommand.pen:
      case BoardCommand.pencil:
      case BoardCommand.dotPen:
        _currentStroke.add(point);
        _updateSmoothStroke(point);
        _updateStrokePreview();
        break;
        
      case BoardCommand.eraser:
        canvasManager.eraseAt(point, radius: _eraserRadius);
        break;
        
      case BoardCommand.shapes:
        _currentShapeEnd = point;
        _updateShapePreview();
        break;
        
      case BoardCommand.tables:
        _currentShapeEnd = point;
        _updateTablePreview();
        break;
        
      default:
        break;
    }
    notifyListeners();
  }

  void onPanEnd() {
    if (!_isDrawing || _activeTool == null) return;

    _isDrawing = false;
    _previewItem = null;

    switch (_activeTool!) {
      case BoardCommand.pen:
        _commitStroke(isEraser: false, isDot: false, isPencil: false);
        break;
        
      case BoardCommand.pencil:
        _commitStroke(isEraser: false, isDot: false, isPencil: true);
        break;
        
      case BoardCommand.dotPen:
        _commitStroke(isEraser: false, isDot: true, isPencil: false);
        break;
        
      case BoardCommand.eraser:
        // Erasing is handled in onPanStart and onPanUpdate
        break;
        
      case BoardCommand.shapes:
        _commitShape();
        break;
        
      case BoardCommand.tables:
        _commitTable();
        break;
        
      default:
        break;
    }

    _currentStroke.clear();
    _smoothedStroke.clear();
    _shapeStart = null;
    _currentShapeEnd = null;
    notifyListeners();
  }

  void _updateSmoothStroke(Offset newPoint) {
    if (_smoothedStroke.isEmpty) {
      _smoothedStroke.add(newPoint);
      return;
    }

    final lastPoint = _smoothedStroke.last;
    final distance = (newPoint - lastPoint).distance;
    
    // Only add point if it's far enough from the last point for smoothness
    if (distance > 2.0) {
      // Add interpolated points for ultra-smooth curves
      final steps = (distance / 3.0).ceil();
      for (int i = 1; i <= steps; i++) {
        final t = i / steps;
        final interpolated = Offset.lerp(lastPoint, newPoint, t)!;
        _smoothedStroke.add(interpolated);
      }
    }
  }

  void _updateStrokePreview() {
    if (_smoothedStroke.length < 2) return;
    
    _previewItem = StrokeItem(
      id: 'preview',
      zIndex: 999999, // Always on top
      points: List.from(_smoothedStroke),
      color: canvasManager.color,
      strokeWidth: canvasManager.strokeWidth,
      opacity: 0.8, // Slightly transparent for preview
      isEraser: false, // Eraser doesn't use stroke preview
      isDot: _activeTool == BoardCommand.dotPen,
      isPencil: _activeTool == BoardCommand.pencil,
    );
  }

  void _updateShapePreview() {
    if (_shapeStart == null || _currentShapeEnd == null) return;
    
    _previewItem = ShapeItem(
      id: 'preview',
      zIndex: 999999,
      shape: _selectedShape,
      start: _shapeStart!,
      end: _currentShapeEnd!,
      color: _selectedShapeColor.withValues(alpha: 0.6),
      strokeWidth: canvasManager.strokeWidth,
    );
  }

  void _updateTablePreview() {
    if (_shapeStart == null || _currentShapeEnd == null) return;
    
    final rect = Rect.fromPoints(_shapeStart!, _currentShapeEnd!);
    if (rect.width < 20 || rect.height < 20) return;
    
    const rows = 3;
    const cols = 3;
    final cellW = rect.width / cols;
    final cellH = rect.height / rows;

    _previewItem = TableItem(
      id: 'preview',
      zIndex: 999999,
      origin: rect.topLeft,
      rows: rows,
      cols: cols,
      cellW: cellW,
      cellH: cellH,
      color: canvasManager.color.withValues(alpha: 0.6),
      strokeWidth: canvasManager.strokeWidth,
    );
  }

  void _commitStroke({
    required bool isEraser,
    required bool isDot,
    required bool isPencil,
  }) {
    if (_smoothedStroke.length < 2) return;

    final stroke = StrokeItem(
      id: _generateId(),
      zIndex: canvasManager.nextZ(),
      points: List.from(_smoothedStroke),
      color: canvasManager.color,
      strokeWidth: canvasManager.strokeWidth,
      isEraser: isEraser,
      isDot: isDot,
      isPencil: isPencil,
    );

    canvasManager.addItem(stroke);
  }

  void _commitShape() {
    if (_shapeStart == null || _currentShapeEnd == null) return;

    final rect = Rect.fromPoints(_shapeStart!, _currentShapeEnd!);
    if (rect.width < 5 || rect.height < 5) return; // Minimum size
    
    final shape = ShapeItem(
      id: _generateId(),
      zIndex: canvasManager.nextZ(),
      shape: _selectedShape,
      start: _shapeStart!,
      end: _currentShapeEnd!,
      color: _selectedShapeColor,
      strokeWidth: canvasManager.strokeWidth,
    );

    canvasManager.addItem(shape);
  }

  void _commitTable() {
    if (_shapeStart == null || _currentShapeEnd == null) return;

    final rect = Rect.fromPoints(_shapeStart!, _currentShapeEnd!);
    if (rect.width < 30 || rect.height < 30) return; // Minimum table size
    
    const rows = 3;
    const cols = 3;
    final cellW = rect.width / cols;
    final cellH = rect.height / rows;

    final table = TableItem(
      id: _generateId(),
      zIndex: canvasManager.nextZ(),
      origin: rect.topLeft,
      rows: rows,
      cols: cols,
      cellW: cellW,
      cellH: cellH,
      color: canvasManager.color,
      strokeWidth: canvasManager.strokeWidth,
    );

    canvasManager.addItem(table);
  }

  void _showFormulaAt(Offset point) {
    // For formula tool, we'll show a modal or floating panel
    // This is handled by the UI layer, not the drawing integration
    _isDrawing = false;
  }

  void _cancelCurrentDrawing() {
    _isDrawing = false;
    _currentStroke.clear();
    _smoothedStroke.clear();
    _shapeStart = null;
    _currentShapeEnd = null;
    _previewItem = null;
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
  }
}