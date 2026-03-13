import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../file_system/file_models.dart';

class SessionMeta {
  SessionMeta({
    required this.id,
    required this.name,
    required this.timestampMs,
    required this.thumbnailPng,
  });

  final String id;
  final String name;
  final int timestampMs;
  final Uint8List thumbnailPng;

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "timestampMs": timestampMs,
    "thumbnailPng": thumbnailPng,
  };

  static SessionMeta fromJson(Map<String, dynamic> j) => SessionMeta(
    id: j["id"],
    name: j["name"],
    timestampMs: j["timestampMs"],
    thumbnailPng: (j["thumbnailPng"] as Uint8List),
  );
}

class SessionPayload {
  SessionPayload({
    required this.meta,
    required this.boardJsonString,
    required this.files,
  });

  final SessionMeta meta;
  final String
  boardJsonString; // includes strokes/shapes/text etc from CanvasManager
  final List<BoardFile> files;

  Map<String, dynamic> toJson() => {
    "meta": meta.toJson(),
    "boardJsonString": boardJsonString,
    "files": files.map((e) => e.toJson()).toList(),
  };

  static SessionPayload fromJson(Map<String, dynamic> j) => SessionPayload(
    meta: SessionMeta.fromJson(Map<String, dynamic>.from(j["meta"])),
    boardJsonString: j["boardJsonString"],
    files: (j["files"] as List)
        .map((e) => BoardFile.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class SessionStorage {
  static const _boxName = "raptor_sessions";
  static const int maxSessions = 10;

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  Future<void> save(SessionPayload payload) async {
    await _box.put(payload.meta.id, payload.toJson());
    await _cleanupOld();
  }

  Future<List<SessionMeta>> listMetas() async {
    final metas = <SessionMeta>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        metas.add(SessionMeta.fromJson(Map<String, dynamic>.from(map["meta"])));
      }
    }
    metas.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return metas;
  }

  Future<SessionPayload?> load(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(raw as Map);
    return SessionPayload.fromJson(map);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> _cleanupOld() async {
    final metas = await listMetas();
    if (metas.length <= maxSessions) return;

    final extra = metas.sublist(maxSessions); // oldest ones beyond limit
    for (final m in extra) {
      await delete(m.id);
    }
  }
}
