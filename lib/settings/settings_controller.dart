import 'package:flutter/foundation.dart';
import 'app_settings.dart';
import 'settings_store.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final SettingsStore _store;
  AppSettings settings = AppSettings();
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    settings = await _store.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _commit() async {
    await _store.save(settings);
    notifyListeners();
  }

  Future<void> setDarkMode(bool v) async {
    settings.darkMode = v;
    await _commit();
  }

  Future<void> setImageResultCount(int v) async {
    settings.imageResultCount = v;
    await _commit();
  }

  Future<void> setPenThickness(double v) async {
    settings.penThickness = v;
    await _commit();
  }

  Future<void> setAutoSaveCanvas(bool v) async {
    settings.autoSaveCanvas = v;
    await _commit();
  }

  Future<void> resetToDefaults() async {
    settings = AppSettings(); // default constructor
    await _commit();
  }

  Future<void> setCanvasBackground(CanvasBackground v) async {
    settings.canvasBackground = v;
    await _commit();
  }

  Future<void> setImageAutoInsert(bool v) async {
    settings.imageAutoInsert = v;
    await _commit();
  }

  // ===== Toolbar visibility =====
  Future<void> setShowPen(bool v) async {
    settings.showPen = v;
    await _commit();
  }

  Future<void> setShowPencil(bool v) async {
    settings.showPencil = v;
    await _commit();
  }

  Future<void> setShowEraser(bool v) async {
    settings.showEraser = v;
    await _commit();
  }

  Future<void> setShowShapes(bool v) async {
    settings.showShapes = v;
    await _commit();
  }

  Future<void> setShowColour(bool v) async {
    settings.showColour = v;
    await _commit();
  }

  Future<void> setShowFormula(bool v) async {
    settings.showFormula = v;
    await _commit();
  }

  Future<void> setShowDotPen(bool v) async {
    settings.showDotPen = v;
    await _commit();
  }

  Future<void> setShowTables(bool v) async {
    settings.showTables = v;
    await _commit();
  }

  Future<void> setShowCrop(bool v) async {
    settings.showCrop = v;
    await _commit();
  }

  Future<void> setShowMove(bool v) async {
    settings.showMove = v;
    await _commit();
  }

  Future<void> setShowSpotlight(bool v) async {
    settings.showSpotlight = v;
    await _commit();
  }

  Future<void> setShowFiles(bool v) async {
    settings.showFiles = v;
    await _commit();
  }
}
