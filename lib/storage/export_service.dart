import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ExportService {
  Future<String> savePngBytes(Uint8List pngBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, "raptor_exports"));
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final ts = DateTime.now().toIso8601String().replaceAll(":", "-");
    final filename = "board_$ts.png";
    final outPath = p.join(outDir.path, filename);

    final f = File(outPath);
    await f.writeAsBytes(pngBytes, flush: true);
    return outPath;
  }
}
