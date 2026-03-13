import 'dart:typed_data';

enum BoardFileType { image, csv, json, pdf, unknown }

BoardFileType detectType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith(".png") ||
      lower.endsWith(".jpg") ||
      lower.endsWith(".jpeg") ||
      lower.endsWith(".gif")) {
    return BoardFileType.image;
  }
  if (lower.endsWith(".csv")) return BoardFileType.csv;
  if (lower.endsWith(".json")) return BoardFileType.json;
  if (lower.endsWith(".pdf")) return BoardFileType.pdf;
  return BoardFileType.unknown;
}

class BoardFile {
  BoardFile({
    required this.id,
    required this.name,
    required this.type,
    required this.localPath,
    required this.sizeBytes,
    required this.createdAtMs,
    this.thumbnailPng,
  });

  final String id;
  final String name;
  final BoardFileType type;
  final String localPath;
  final int sizeBytes;
  final int createdAtMs;

  /// small thumbnail stored as PNG bytes (compressed)
  final Uint8List? thumbnailPng;

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "type": type.name,
    "localPath": localPath,
    "sizeBytes": sizeBytes,
    "createdAtMs": createdAtMs,
    "thumbnailPng": thumbnailPng, // Hive supports Uint8List
  };

  static BoardFile fromJson(Map<String, dynamic> j) => BoardFile(
    id: j["id"],
    name: j["name"],
    type: BoardFileType.values.firstWhere(
      (e) => e.name == j["type"],
      orElse: () => BoardFileType.unknown,
    ),
    localPath: j["localPath"],
    sizeBytes: j["sizeBytes"],
    createdAtMs: j["createdAtMs"],
    thumbnailPng: (j["thumbnailPng"] as Uint8List?),
  );
}

class PendingPlacement {
  PendingPlacement({required this.file, this.scale = 1.0});

  final BoardFile file;
  final double scale;
}
