import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/file_cache.dart';
import '../storage/session_storage.dart';
import '../file_system/file_models.dart';

class FileController extends ChangeNotifier {
  FileController({required FileCache cache, required SessionStorage sessions})
    : _cache = cache,
      _sessions = sessions;

  final FileCache _cache;
  final SessionStorage _sessions;

  // Repository
  final List<BoardFile> _repo = [];
  List<BoardFile> get repo => List.unmodifiable(_repo);

  // Upload state
  bool isUploading = false;
  double uploadProgress = 0;
  String? uploadError;

  // Pending placement (after upload)
  PendingPlacement? pendingPlacement;

  // Helpers
  Future<void> init() async {
    await _sessions.init();
    // In future: load repo index from disk; for now repo is in-memory per run.
  }

  Future<void> importFiles(List<File> files) async {
    uploadError = null;
    isUploading = true;
    uploadProgress = 0;
    notifyListeners();

    try {
      final total = files.length;
      int done = 0;

      for (final f in files) {
        // validate size inside cache.importFile
        final bf = await _cache.importFile(f);
        _repo.add(bf);
        done++;
        uploadProgress = done / total;
        notifyListeners();
      }

      // After upload: set first file as pending placement
      if (_repo.isNotEmpty) {
        pendingPlacement = PendingPlacement(file: _repo.last);
      }
    } catch (e) {
      uploadError = e.toString();
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  void clearPendingPlacement() {
    pendingPlacement = null;
    notifyListeners();
  }

  void setPending(BoardFile f) {
    pendingPlacement = PendingPlacement(file: f);
    notifyListeners();
  }

  Future<String> readAsPreviewText(BoardFile f) async {
    final file = File(f.localPath);
    if (!await file.exists()) return "(Missing file)";

    if (f.type == BoardFileType.csv || f.type == BoardFileType.json) {
      final raw = await file.readAsString();

      // Keep preview small to avoid UI freeze
      if (raw.length > 3000) {
        return "${raw.substring(0, 3000)}\n...\n(Preview truncated)";
      }

      // Pretty print JSON if possible
      if (f.type == BoardFileType.json) {
        try {
          final obj = jsonDecode(raw);
          return const JsonEncoder.withIndent("  ").convert(obj);
        } catch (_) {
          return raw;
        }
      }
      return raw;
    }

    return "(Preview not available for this file type)";
  }

  // ===== Sessions =====

  Future<void> saveSession({
    required String sessionId,
    required String sessionName,
    required String boardJsonString,
    required Uint8List thumbnailPng,
  }) async {
    final payload = SessionPayload(
      meta: SessionMeta(
        id: sessionId,
        name: sessionName,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        thumbnailPng: thumbnailPng,
      ),
      boardJsonString: boardJsonString,
      files: List<BoardFile>.from(_repo),
    );
    await _sessions.save(payload);
  }

  Future<List<SessionMeta>> listSessions() => _sessions.listMetas();

  Future<SessionPayload?> loadSession(String id) => _sessions.load(id);

  Future<void> deleteSession(String id) => _sessions.delete(id);

  // ===== Delete a file =====
  Future<void> deleteFile(BoardFile f) async {
    _repo.removeWhere((e) => e.id == f.id);
    if (pendingPlacement?.file.id == f.id) pendingPlacement = null;
    notifyListeners();
    await _cache.delete(f);
  }
}
