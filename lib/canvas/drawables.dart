import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum DrawableType { stroke, shape, table, text, image }

abstract class DrawableItem {
  String get id;
  int get zIndex;
  DrawableType get type;

  Rect get bounds;

  /// Draw this item onto canvas
  void draw(Canvas canvas);

  /// Return a translated copy (for move tool & commands)
  DrawableItem translated(Offset delta);

  Map<String, dynamic> toJson();
}

/// ---------------- STROKE ITEM ----------------
class StrokeItem implements DrawableItem {
  StrokeItem({
    required this.id,
    required this.zIndex,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.opacity = 1.0,
    this.isEraser = false,
    this.isDot = false,
    this.isPencil = false,
  });

  @override
  final String id;

  @override
  final int zIndex;

  @override
  final DrawableType type = DrawableType.stroke;

  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;

  final bool isEraser;
  final bool isDot;
  final bool isPencil;

  @override
  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.dx, minY = points.first.dy;
    double maxX = points.first.dx, maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    final pad = strokeWidth * 1.2;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  @override
  void draw(Canvas canvas) {
    if (points.length < 2) return;

    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isEraser) {
      paint.blendMode = BlendMode.clear;
      paint.color = const Color(0x00000000);
    } else {
      paint.color = color.withOpacity(opacity);
    }

    if (isPencil) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
    }

    if (isDot) {
      _drawDots(canvas, paint, points, spacing: strokeWidth * 2.2);
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);

    if (isPencil) {
      final grain = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = color.withOpacity(0.18);
      for (int i = 2; i < points.length; i += 3) {
        final a = points[i - 1];
        final b = points[i];
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        canvas.drawLine(mid, mid + const Offset(0.8, -0.6), grain);
      }
    }
  }

  void _drawDots(
    Canvas canvas,
    Paint paint,
    List<Offset> pts, {
    required double spacing,
  }) {
    if (pts.isEmpty) return;

    // first dot
    canvas.drawCircle(
      pts.first,
      paint.strokeWidth / 2,
      paint..style = PaintingStyle.fill,
    );

    if (pts.length < 2) return;

    double totalDistance = 0;
    double nextDotDistance = spacing;

    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final current = pts[i];
      final segmentLength = (current - prev).distance;

      if (segmentLength == 0) continue;

      final segmentDirection = (current - prev) / segmentLength;
      double segmentProgress = 0;

      while (segmentProgress < segmentLength) {
        final remainingToNextDot = nextDotDistance - totalDistance;

        if (segmentProgress + remainingToNextDot <= segmentLength) {
          final dotPosition =
              prev + segmentDirection * (segmentProgress + remainingToNextDot);

          canvas.drawCircle(
            dotPosition,
            paint.strokeWidth / 2,
            paint..style = PaintingStyle.fill,
          );

          segmentProgress += remainingToNextDot;
          totalDistance = 0;
          nextDotDistance = spacing;
        } else {
          totalDistance += segmentLength - segmentProgress;
          break;
        }
      }
    }

    paint.style = PaintingStyle.stroke;
  }

  @override
  DrawableItem translated(Offset delta) {
    return StrokeItem(
      id: id,
      zIndex: zIndex,
      points: points.map((p) => p + delta).toList(),
      color: color,
      strokeWidth: strokeWidth,
      opacity: opacity,
      isEraser: isEraser,
      isDot: isDot,
      isPencil: isPencil,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    "type": "stroke",
    "id": id,
    "z": zIndex,
    "points": points.map((p) => [p.dx, p.dy]).toList(),
    "color": color.value,
    "w": strokeWidth,
    "op": opacity,
    "eraser": isEraser,
    "dot": isDot,
    "pencil": isPencil,
  };

  static StrokeItem fromJson(Map<String, dynamic> j) {
    return StrokeItem(
      id: j["id"],
      zIndex: j["z"],
      points: (j["points"] as List)
          .map((e) => Offset(e[0].toDouble(), e[1].toDouble()))
          .toList(),
      color: Color(j["color"]),
      strokeWidth: (j["w"] as num).toDouble(),
      opacity: (j["op"] as num).toDouble(),
      isEraser: j["eraser"] == true,
      isDot: j["dot"] == true,
      isPencil: j["pencil"] == true,
    );
  }
}

/// ---------------- SHAPE ITEM ----------------
enum ShapeType {
  rectangle,
  roundedRect,
  circle,
  ellipse,
  triangle,
  diamond,
  line,
  arrow,
}

class ShapeItem implements DrawableItem {
  ShapeItem({
    required this.id,
    required this.zIndex,
    required this.shape,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
    this.cornerRadius = 16,
  });

  @override
  final String id;

  @override
  final int zIndex;

  @override
  final DrawableType type = DrawableType.shape;

  final ShapeType shape;
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;
  final double cornerRadius;

  Rect get rect => Rect.fromPoints(start, end);

  @override
  Rect get bounds => rect.inflate(strokeWidth * 1.2);

  @override
  void draw(Canvas canvas) {
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final r = rect;

    switch (shape) {
      case ShapeType.rectangle:
        canvas.drawRect(r, paint);
        break;
      case ShapeType.roundedRect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(cornerRadius)),
          paint,
        );
        break;
      case ShapeType.circle:
        canvas.drawCircle(r.center, r.shortestSide.abs() / 2, paint);
        break;
      case ShapeType.ellipse:
        canvas.drawOval(r, paint);
        break;
      case ShapeType.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(r.center.dx, r.top)
            ..lineTo(r.right, r.bottom)
            ..lineTo(r.left, r.bottom)
            ..close(),
          paint,
        );
        break;
      case ShapeType.diamond:
        canvas.drawPath(
          Path()
            ..moveTo(r.center.dx, r.top)
            ..lineTo(r.right, r.center.dy)
            ..lineTo(r.center.dx, r.bottom)
            ..lineTo(r.left, r.center.dy)
            ..close(),
          paint,
        );
        break;
      case ShapeType.line:
        canvas.drawLine(start, end, paint);
        break;
      case ShapeType.arrow:
        canvas.drawLine(start, end, paint);
        canvas.drawPath(_arrowHead(start, end, 14), paint);
        break;
    }
  }

  Path _arrowHead(Offset a, Offset b, double size) {
    final v = (a - b);
    final len = v.distance == 0 ? 1.0 : v.distance;
    final ux = v.dx / len;
    final uy = v.dy / len;

    final left = Offset(
      b.dx + (ux * size) - (uy * size * 0.6),
      b.dy + (uy * size) + (ux * size * 0.6),
    );
    final right = Offset(
      b.dx + (ux * size) + (uy * size * 0.6),
      b.dy + (uy * size) - (ux * size * 0.6),
    );

    return Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo(left.dx, left.dy)
      ..moveTo(b.dx, b.dy)
      ..lineTo(right.dx, right.dy);
  }

  @override
  DrawableItem translated(Offset delta) {
    return ShapeItem(
      id: id,
      zIndex: zIndex,
      shape: shape,
      start: start + delta,
      end: end + delta,
      color: color,
      strokeWidth: strokeWidth,
      cornerRadius: cornerRadius,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    "type": "shape",
    "id": id,
    "z": zIndex,
    "shape": shape.index,
    "start": [start.dx, start.dy],
    "end": [end.dx, end.dy],
    "color": color.value,
    "w": strokeWidth,
    "cr": cornerRadius,
  };

  static ShapeItem fromJson(Map<String, dynamic> j) {
    return ShapeItem(
      id: j["id"],
      zIndex: j["z"],
      shape: ShapeType.values[j["shape"]],
      start: Offset(
        (j["start"][0] as num).toDouble(),
        (j["start"][1] as num).toDouble(),
      ),
      end: Offset(
        (j["end"][0] as num).toDouble(),
        (j["end"][1] as num).toDouble(),
      ),
      color: Color(j["color"]),
      strokeWidth: (j["w"] as num).toDouble(),
      cornerRadius: (j["cr"] as num).toDouble(),
    );
  }
}

/// ---------------- TABLE ITEM ----------------
class TableItem implements DrawableItem {
  TableItem({
    required this.id,
    required this.zIndex,
    required this.origin,
    required this.rows,
    required this.cols,
    required this.cellW,
    required this.cellH,
    required this.color,
    required this.strokeWidth,
  });

  @override
  final String id;

  @override
  final int zIndex;

  @override
  final DrawableType type = DrawableType.table;

  final Offset origin;
  final int rows;
  final int cols;
  final double cellW;
  final double cellH;

  final Color color;
  final double strokeWidth;

  Rect get rect => origin & Size(cols * cellW, rows * cellH);

  @override
  Rect get bounds => rect.inflate(strokeWidth * 1.2);

  @override
  void draw(Canvas canvas) {
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    final r = rect;
    canvas.drawRect(r, paint);

    for (int c = 1; c < cols; c++) {
      final x = r.left + c * cellW;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), paint);
    }
    for (int rr = 1; rr < rows; rr++) {
      final y = r.top + rr * cellH;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
    }
  }

  @override
  DrawableItem translated(Offset delta) {
    return TableItem(
      id: id,
      zIndex: zIndex,
      origin: origin + delta,
      rows: rows,
      cols: cols,
      cellW: cellW,
      cellH: cellH,
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    "type": "table",
    "id": id,
    "z": zIndex,
    "o": [origin.dx, origin.dy],
    "r": rows,
    "c": cols,
    "cw": cellW,
    "ch": cellH,
    "color": color.value,
    "w": strokeWidth,
  };

  static TableItem fromJson(Map<String, dynamic> j) {
    return TableItem(
      id: j["id"],
      zIndex: j["z"],
      origin: Offset(
        (j["o"][0] as num).toDouble(),
        (j["o"][1] as num).toDouble(),
      ),
      rows: j["r"],
      cols: j["c"],
      cellW: (j["cw"] as num).toDouble(),
      cellH: (j["ch"] as num).toDouble(),
      color: Color(j["color"]),
      strokeWidth: (j["w"] as num).toDouble(),
    );
  }
}

/// ---------------- TEXT ITEM ----------------
/// Updated to wrap text within a maxWidth and paint a soft background for readability.
class TextItem implements DrawableItem {
  TextItem({
    required this.id,
    required this.zIndex,
    required this.text,
    required this.position,
    required this.fontSize,
    required this.color,
    this.maxWidth = 520,
    this.padding = 10,
    this.drawBackground = true,
  });

  @override
  final String id;

  @override
  final int zIndex;

  @override
  final DrawableType type = DrawableType.text;

  final String text;
  final Offset position;
  final double fontSize;
  final Color color;

  // New
  final double maxWidth;
  final double padding;
  final bool drawBackground;

  TextPainter _buildPainter() {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
  }

  @override
  Rect get bounds {
    final tp = _buildPainter();
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      tp.width + padding * 2,
      tp.height + padding * 2,
    ).inflate(6);
  }

  @override
  void draw(Canvas canvas) {
    final tp = _buildPainter();

    if (drawBackground) {
      final bgRect = Rect.fromLTWH(
        position.dx,
        position.dy,
        tp.width + padding * 2,
        tp.height + padding * 2,
      );

      final bgPaint = Paint()..color = const Color(0x14FFFFFF);
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22000000);

      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(12)),
        bgPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(12)),
        borderPaint,
      );
    }

    tp.paint(canvas, position + Offset(padding, padding));
  }

  @override
  DrawableItem translated(Offset delta) {
    return TextItem(
      id: id,
      zIndex: zIndex,
      text: text,
      position: position + delta,
      fontSize: fontSize,
      color: color,
      maxWidth: maxWidth,
      padding: padding,
      drawBackground: drawBackground,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    "type": "text",
    "id": id,
    "z": zIndex,
    "t": text,
    "p": [position.dx, position.dy],
    "fs": fontSize,
    "color": color.value,
    "mw": maxWidth,
    "pad": padding,
    "bg": drawBackground,
  };

  static TextItem fromJson(Map<String, dynamic> j) {
    return TextItem(
      id: j["id"],
      zIndex: j["z"],
      text: j["t"],
      position: Offset(
        (j["p"][0] as num).toDouble(),
        (j["p"][1] as num).toDouble(),
      ),
      fontSize: (j["fs"] as num).toDouble(),
      color: Color(j["color"]),
      maxWidth: ((j["mw"] ?? 520) as num).toDouble(),
      padding: ((j["pad"] ?? 10) as num).toDouble(),
      drawBackground: (j["bg"] ?? true) == true,
    );
  }
}

/// ---------------- IMAGE ITEM ----------------
/// Stores PNG/JPG bytes as base64 so sessions persist images.
/// Draw uses a cached decoded ui.Image for performance.
class ImageItem implements DrawableItem {
  ImageItem({
    required this.id,
    required this.zIndex,
    required this.rect,
    required this.imageBytesB64,
  });

  @override
  final String id;

  @override
  final int zIndex;

  @override
  final DrawableType type = DrawableType.image;

  final Rect rect;
  final String imageBytesB64;

  ui.Image? _image;

  Future<void> ensureDecoded() async {
    if (_image != null) return;

    final bytes = base64Decode(imageBytesB64);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _image = frame.image;
  }

  @override
  Rect get bounds => rect;

  @override
  void draw(Canvas canvas) {
    final img = _image;
    if (img == null) {
      final paint = Paint()..color = const Color(0x22000000);
      canvas.drawRect(rect, paint);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x33000000);
      canvas.drawRect(rect, border);
      return;
    }

    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    canvas.drawImageRect(img, src, rect, Paint());
  }

  @override
  DrawableItem translated(Offset delta) {
    final copy = ImageItem(
      id: id,
      zIndex: zIndex,
      rect: rect.shift(delta),
      imageBytesB64: imageBytesB64,
    );
    copy._image = _image; // keep cache
    return copy;
  }

  @override
  Map<String, dynamic> toJson() => {
    "type": "image",
    "id": id,
    "z": zIndex,
    "rect": [rect.left, rect.top, rect.right, rect.bottom],
    "b64": imageBytesB64,
  };

  static ImageItem fromJson(Map<String, dynamic> j) {
    final r = (j["rect"] as List).cast<num>();
    return ImageItem(
      id: j["id"] as String,
      zIndex: (j["z"] ?? 0) as int,
      rect: Rect.fromLTRB(
        r[0].toDouble(),
        r[1].toDouble(),
        r[2].toDouble(),
        r[3].toDouble(),
      ),
      imageBytesB64: (j["b64"] ?? "") as String,
    );
  }
}

/// JSON factory
DrawableItem drawableFromJson(Map<String, dynamic> j) {
  switch (j["type"]) {
    case "stroke":
      return StrokeItem.fromJson(j);
    case "shape":
      return ShapeItem.fromJson(j);
    case "table":
      return TableItem.fromJson(j);
    case "text":
      return TextItem.fromJson(j);
    case "image":
      return ImageItem.fromJson(j);
  }
  throw UnsupportedError("Unknown drawable type: ${j["type"]}");
}
