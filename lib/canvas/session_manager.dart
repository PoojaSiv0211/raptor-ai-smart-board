import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'canvas_manager.dart';

class SessionManager {
  const SessionManager();

  Future<File> _sessionFile(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File("${dir.path}/$name.smartboard.json");
  }

  Future<void> saveSession(
    CanvasManager vm, {
    String name = "last_session",
  }) async {
    final f = await _sessionFile(name);
    await f.writeAsString(jsonEncode(vm.toJson()));
  }

  Future<bool> loadSession(
    CanvasManager vm, {
    String name = "last_session",
  }) async {
    final f = await _sessionFile(name);
    if (!await f.exists()) return false;
    final raw = await f.readAsString();
    vm.loadFromJson(jsonDecode(raw));
    return true;
  }
}
