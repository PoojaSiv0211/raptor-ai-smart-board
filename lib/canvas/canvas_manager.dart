import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/free_ai_service.dart';
import 'command_system.dart';
import 'drawables.dart';

enum EditMode { draw, crop, move, spotlight, circleSearch }

class CanvasManager extends ChangeNotifier {
  CanvasManager({CommandStack? stack})
    : _stack = stack ?? CommandStack(limit: 50);

  final CommandStack _stack;

  final List<DrawableItem> _items = [];
  List<DrawableItem> get items => List.unmodifiable(_items);

  int _zCounter = 0;

  Color color = Colors.black;
  double strokeWidth = 4;

  EditMode mode = EditMode.draw;

  Rect? cropRect;
  Rect? cropPreviewRect;

  String? selectedId;

  bool spotlightEnabled = false;
  Offset spotlightPosition = Offset.zero;
  double spotlightRadius = 110;

  ui.Picture? _cache;
  Size? _cacheSize;
  bool _cacheDirty = true;

  ui.Picture? get cachedPicture => _cache;

  final FreeAiService _freeAiService = FreeAiService(
    circleSearchEndpoint: 'http://127.0.0.1:5000/circle-search',
  );

  final List<Offset> _circleSearchPoints = <Offset>[];
  String? _circleSearchResult;
  String? _circleSearchError;
  bool _isCircleSearchLoading = false;

  List<Offset> get circleSearchPoints => List.unmodifiable(_circleSearchPoints);
  String? get circleSearchResult => _circleSearchResult;
  String? get circleSearchError => _circleSearchError;
  bool get isCircleSearchLoading => _isCircleSearchLoading;
  bool get hasCircleSearchSelection => _circleSearchPoints.length > 5;

  void run(CanvasCommand cmd) {
    _stack.run(cmd);
    notifyListeners();
  }

  void undo() {
    _stack.undo();
    _cacheDirty = true;
    notifyListeners();
  }

  void redo() {
    _stack.redo();
    _cacheDirty = true;
    notifyListeners();
  }

  bool get canUndo => _stack.canUndo;
  bool get canRedo => _stack.canRedo;

  void setStrokeWidth(double w) {
    strokeWidth = w.clamp(1, 40);
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    notifyListeners();
  }

  void setMode(EditMode m) {
    mode = m;
    if (m != EditMode.spotlight) {
      spotlightEnabled = false;
    }
    notifyListeners();
  }

  void startSpotlight(Offset p) {
    spotlightEnabled = true;
    spotlightPosition = p;
    notifyListeners();
  }

  void updateSpotlight(Offset p) {
    spotlightPosition = p;
    notifyListeners();
  }

  void stopSpotlight() {
    spotlightEnabled = false;
    notifyListeners();
  }

  void startCropPreview(Offset p) {
    cropPreviewRect = Rect.fromPoints(p, p);
    notifyListeners();
  }

  void updateCropPreview(Offset start, Offset current) {
    cropPreviewRect = Rect.fromPoints(start, current);
    notifyListeners();
  }

  void cancelCropPreview() {
    cropPreviewRect = null;
    notifyListeners();
  }

  void startCircleSearchLasso(Offset point) {
    _circleSearchPoints
      ..clear()
      ..add(point);
    _circleSearchError = null;
    notifyListeners();
  }

  void updateCircleSearchLasso(Offset point) {
    _circleSearchPoints.add(point);
    notifyListeners();
  }

  void clearCircleSearchSelection() {
    _circleSearchPoints.clear();
    _circleSearchError = null;
    _circleSearchResult = null;
    _isCircleSearchLoading = false;
    notifyListeners();
  }

  void setCircleSearchResult(String? value) {
    _circleSearchResult = value;
    notifyListeners();
  }

  Future<void> runCircleSearch(Size boardSize) async {
    if (_circleSearchPoints.length < 3) {
      _circleSearchError = 'Draw a circle or lasso around something first.';
      notifyListeners();
      return;
    }

    _circleSearchError = null;
    _circleSearchResult = null;
    _isCircleSearchLoading = true;
    notifyListeners();

    try {
      final Uint8List boardBytes = await exportPngBytes(
        boardSize,
        pixelRatio: 1.0,
      );

      final Uint8List? croppedBytes = await _cropCircleSearchRegion(boardBytes);

      if (croppedBytes == null || croppedBytes.isEmpty) {
        throw Exception('Could not crop selected region.');
      }

      final String result = await _freeAiService.circleSearchFromImageBytes(
        croppedBytes,
      );

      _circleSearchResult = result.trim().isEmpty
          ? 'No result returned.'
          : result.trim();
      _circleSearchError = null;
    } catch (e) {
      _circleSearchError = 'Search failed: $e';
    } finally {
      _isCircleSearchLoading = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> _cropCircleSearchRegion(Uint8List boardBytes) async {
    try {
      if (_circleSearchPoints.length < 3) return null;

      final codec = await ui.instantiateImageCodec(boardBytes);
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      double minX = _circleSearchPoints.first.dx;
      double minY = _circleSearchPoints.first.dy;
      double maxX = _circleSearchPoints.first.dx;
      double maxY = _circleSearchPoints.first.dy;

      for (final Offset p in _circleSearchPoints) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }

      const double padding = 32.0;

      final double srcLeft = (minX - padding).clamp(
        0.0,
        image.width.toDouble() - 1,
      );
      final double srcTop = (minY - padding).clamp(
        0.0,
        image.height.toDouble() - 1,
      );
      final double srcRight = (maxX + padding).clamp(
        1.0,
        image.width.toDouble(),
      );
      final double srcBottom = (maxY + padding).clamp(
        1.0,
        image.height.toDouble(),
      );

      final int cropWidth = math.max(1, (srcRight - srcLeft).round());
      final int cropHeight = math.max(1, (srcBottom - srcTop).round());

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      final Rect srcRect = Rect.fromLTWH(
        srcLeft,
        srcTop,
        cropWidth.toDouble(),
        cropHeight.toDouble(),
      );

      final Rect dstRect = Rect.fromLTWH(
        0,
        0,
        cropWidth.toDouble(),
        cropHeight.toDouble(),
      );

      canvas.drawRect(dstRect, Paint()..color = Colors.white);
      canvas.drawImageRect(image, srcRect, dstRect, Paint());

      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedImage = await picture.toImage(
        cropWidth,
        cropHeight,
      );

      final byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Circle crop error: $e');
      return null;
    }
  }

  void eraseAt(Offset point, {double radius = 22}) {
    final itemsToRemove = <String>[];

    for (final item in _items) {
      if (_itemIntersectsCircle(item, point, radius)) {
        itemsToRemove.add(item.id);
      }
    }

    if (itemsToRemove.isNotEmpty) {
      run(_EraseCommand(this, itemsToRemove));
    }
  }

  bool _itemIntersectsCircle(DrawableItem item, Offset center, double radius) {
    final bounds = item.bounds;

    final closestX = center.dx.clamp(bounds.left, bounds.right);
    final closestY = center.dy.clamp(bounds.top, bounds.bottom);
    final distance = (Offset(closestX, closestY) - center).distance;

    return distance <= radius;
  }

  int nextZ() => ++_zCounter;

  void _addItemInternal(DrawableItem item) {
    _items.add(item);
    _items.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    _cacheDirty = true;
  }

  void _removeItemInternal(String id) {
    _items.removeWhere((e) => e.id == id);
    _cacheDirty = true;
  }

  void _replaceItemInternal(String id, DrawableItem newItem) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _items[idx] = newItem;
    _items.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    _cacheDirty = true;
  }

  void replaceItemInternal(String id, DrawableItem newItem) {
    _replaceItemInternal(id, newItem);
  }

  DrawableItem? getById(String id) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return null;
    return _items[idx];
  }

  DrawableItem? hitTest(Offset p) {
    for (int i = _items.length - 1; i >= 0; i--) {
      if (_items[i].bounds.contains(p)) return _items[i];
    }
    return null;
  }

  void applyCrop(Rect rect) {
    run(_CropCommand(this, rect));
  }

  void clearCrop() {
    run(_CropCommand(this, null));
  }

  void clearCanvas() => run(_ClearCommand(this));

  void newBoard() {
    _items.clear();
    cropRect = null;
    cropPreviewRect = null;
    selectedId = null;
    spotlightEnabled = false;
    _circleSearchPoints.clear();
    _circleSearchResult = null;
    _circleSearchError = null;
    _isCircleSearchLoading = false;
    _cacheDirty = true;
    _stack.clearHistory();
    notifyListeners();
  }

  Future<Uint8List> exportPngBytes(Size size, {double pixelRatio = 2.0}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    if (cropRect != null) {
      canvas.save();
      canvas.clipRect(cropRect!);
    }

    for (final it in _items) {
      if (it is StrokeItem && it.isEraser) {
        canvas.saveLayer(Offset.zero & size, Paint());
        it.draw(canvas);
        canvas.restore();
      } else {
        it.draw(canvas);
      }
    }

    if (cropRect != null) {
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  void ensureCache(Size size) {
    if (!_cacheDirty && _cache != null && _cacheSize == size) return;

    _cacheSize = size;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (cropRect != null) {
      canvas.save();
      canvas.clipRect(cropRect!);
    }

    for (final it in _items) {
      if (it is ImageItem) {
        it.ensureDecoded().then((_) {
          _cacheDirty = true;
          notifyListeners();
        });
      }
    }

    for (final it in _items) {
      if (it is StrokeItem && it.isEraser) {
        canvas.saveLayer(Offset.zero & size, Paint());
        it.draw(canvas);
        canvas.restore();
      } else {
        it.draw(canvas);
      }
    }

    if (cropRect != null) {
      canvas.restore();
    }

    _cache = recorder.endRecording();
    _cacheDirty = false;
  }

  Map<String, dynamic> toJson() => {
    'items': _items.map((e) => e.toJson()).toList(),
    'crop': cropRect == null
        ? null
        : [cropRect!.left, cropRect!.top, cropRect!.right, cropRect!.bottom],
    'z': _zCounter,
    'color': color.value,
    'strokeWidth': strokeWidth,
  };

  void loadFromJson(Map<String, dynamic> j) {
    _items
      ..clear()
      ..addAll(
        (j['items'] as List).map(
          (e) => drawableFromJson(Map<String, dynamic>.from(e)),
        ),
      );
    _items.sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final c = j['crop'];
    cropRect = (c == null)
        ? null
        : Rect.fromLTRB(
            (c[0] as num).toDouble(),
            (c[1] as num).toDouble(),
            (c[2] as num).toDouble(),
            (c[3] as num).toDouble(),
          );

    _zCounter = (j['z'] ?? 0) as int;
    color = Color(j['color'] ?? Colors.black.value);
    strokeWidth = ((j['strokeWidth'] ?? 4) as num).toDouble();

    _cacheDirty = true;
    notifyListeners();
  }

  String toJsonString() => jsonEncode(toJson());

  void addItem(DrawableItem item) => run(_AddItemCommand(this, item));
  void moveItem(String id, Offset delta) => run(_MoveCommand(this, id, delta));

  @override
  void dispose() {
    _freeAiService.dispose();
    super.dispose();
  }
}

class _AddItemCommand implements CanvasCommand {
  _AddItemCommand(this.vm, this.item);

  final CanvasManager vm;
  final DrawableItem item;

  @override
  void execute() => vm._addItemInternal(item);

  @override
  void undo() => vm._removeItemInternal(item.id);
}

class _MoveCommand implements CanvasCommand {
  _MoveCommand(this.vm, this.id, this.delta);

  final CanvasManager vm;
  final String id;
  final Offset delta;

  DrawableItem? _before;
  DrawableItem? _after;

  @override
  void execute() {
    _before ??= vm.getById(id);
    final cur = vm.getById(id);
    if (cur == null) return;
    _after = cur.translated(delta);
    vm._replaceItemInternal(id, _after!);
  }

  @override
  void undo() {
    if (_before == null) return;
    vm._replaceItemInternal(id, _before!);
  }
}

class _ClearCommand implements CanvasCommand {
  _ClearCommand(this.vm);

  final CanvasManager vm;
  List<DrawableItem>? _snapshot;
  Rect? _cropSnapshot;

  @override
  void execute() {
    _snapshot ??= List<DrawableItem>.from(vm._items);
    _cropSnapshot ??= vm.cropRect;
    vm._items.clear();
    vm.cropRect = null;
    vm.cropPreviewRect = null;
    vm.selectedId = null;
    vm._cacheDirty = true;
  }

  @override
  void undo() {
    if (_snapshot == null) return;
    vm._items
      ..clear()
      ..addAll(_snapshot!);
    vm.cropRect = _cropSnapshot;
    vm._cacheDirty = true;
  }
}

class _CropCommand implements CanvasCommand {
  _CropCommand(this.vm, this.newRect);

  final CanvasManager vm;
  final Rect? newRect;

  Rect? _prev;

  @override
  void execute() {
    _prev ??= vm.cropRect;
    vm.cropRect = newRect;
    vm.cropPreviewRect = null;
    vm._cacheDirty = true;
  }

  @override
  void undo() {
    vm.cropRect = _prev;
    vm.cropPreviewRect = null;
    vm._cacheDirty = true;
  }
}

class _EraseCommand implements CanvasCommand {
  _EraseCommand(this.vm, this.itemIds);

  final CanvasManager vm;
  final List<String> itemIds;
  List<DrawableItem>? _erasedItems;

  @override
  void execute() {
    _erasedItems ??= itemIds
        .map((id) => vm.getById(id))
        .whereType<DrawableItem>()
        .toList();

    for (final id in itemIds) {
      vm._removeItemInternal(id);
    }
  }

  @override
  void undo() {
    if (_erasedItems == null) return;

    for (final item in _erasedItems!) {
      vm._addItemInternal(item);
    }
  }
}
