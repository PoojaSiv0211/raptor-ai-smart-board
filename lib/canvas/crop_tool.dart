import 'package:flutter/material.dart';
import 'canvas_manager.dart';

class CropToolController {
  CropToolController(this.vm);

  final CanvasManager vm;

  Offset? _start;

  void onStart(Offset p) {
    _start = p;
    vm.startCropPreview(p);
  }

  void onUpdate(Offset p) {
    if (_start == null) return;
    vm.updateCropPreview(_start!, p);
  }

  void onEnd() {
    final r = vm.cropPreviewRect;
    _start = null;

    if (r == null || r.width < 8 || r.height < 8) {
      vm.cancelCropPreview();
      return;
    }

    // ✅ Undoable command
    vm.applyCrop(r);
  }

  void cancel() {
    _start = null;
    vm.cancelCropPreview();
  }
}
