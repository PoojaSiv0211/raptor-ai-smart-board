import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../file_system/file_models.dart';

class FileCache {
  static const int maxFileBytes = 10 * 1024 * 1024; // 10 MB

  Future<Directory> _rootDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, "raptor_files"));
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  String _id() =>
      "${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}";

  Future<BoardFile> importFile(File src) async {
    final size = await src.length();
    if (size > maxFileBytes) {
      throw Exception("File too large. Max size is 10MB.");
    }

    final root = await _rootDir();
    final name = p.basename(src.path);
    final id = _id();
    final dstPath = p.join(root.path, "${id}_$name");

    await src.copy(dstPath);

    final type = detectType(name);

    Uint8List? thumb;
    if (type == BoardFileType.image) {
      thumb = await _makeImageThumb(dstPath);
    } else if (type == BoardFileType.pdf) {
      // PDF thumb can be added later (optional)
      thumb = null;
    }

    return BoardFile(
      id: id,
      name: name,
      type: type,
      localPath: dstPath,
      sizeBytes: size,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      thumbnailPng: thumb,
    );
  }

  Future<Uint8List?> _makeImageThumb(String path) async {
    // compress to small PNG thumbnail (fast + small)
    final out = await FlutterImageCompress.compressWithFile(
      path,
      format: CompressFormat.png,
      minWidth: 256,
      minHeight: 256,
      quality: 80,
    );
    return out;
  }

  Future<void> delete(BoardFile f) async {
    final file = File(f.localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
