import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/free_ai_service.dart';

class CircleSearchInlineOverlay extends StatefulWidget {
  const CircleSearchInlineOverlay({
    super.key,
    required this.previewImageBytes,
    required this.onClose,
    required this.onInsertToBoard,
  });

  final Uint8List previewImageBytes;
  final VoidCallback onClose;
  final Future<void> Function(String text) onInsertToBoard;

  @override
  State<CircleSearchInlineOverlay> createState() =>
      _CircleSearchInlineOverlayState();
}

class _CircleSearchInlineOverlayState extends State<CircleSearchInlineOverlay> {
  final GlobalKey _imageKey = GlobalKey();

  final FreeAiService _freeAiService = FreeAiService(
    circleSearchEndpoint: 'http://127.0.0.1:5000/circle-search',
  );

  final List<Offset> _lassoPoints = <Offset>[];

  bool _isSearching = false;
  String? _resultText;
  String? _errorText;

  bool get _hasSelection => _lassoPoints.length > 5;

  void _clearSelection() {
    setState(() {
      _lassoPoints.clear();
      _resultText = null;
      _errorText = null;
    });
  }

  Future<Uint8List?> _cropSelectedRegion() async {
    try {
      if (_lassoPoints.length < 3) return null;

      final codec = await ui.instantiateImageCodec(widget.previewImageBytes);
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      double minX = _lassoPoints.first.dx;
      double minY = _lassoPoints.first.dy;
      double maxX = _lassoPoints.first.dx;
      double maxY = _lassoPoints.first.dy;

      for (final Offset p in _lassoPoints) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }

      final RenderBox? renderBox =
          _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return null;

      final Size displaySize = renderBox.size;
      if (displaySize.width <= 0 || displaySize.height <= 0) return null;

      final double scaleX = image.width / displaySize.width;
      final double scaleY = image.height / displaySize.height;

      final double srcLeft = (minX * scaleX).clamp(
        0.0,
        image.width.toDouble() - 1,
      );
      final double srcTop = (minY * scaleY).clamp(
        0.0,
        image.height.toDouble() - 1,
      );
      final double srcRight = (maxX * scaleX).clamp(
        1.0,
        image.width.toDouble(),
      );
      final double srcBottom = (maxY * scaleY).clamp(
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

      canvas.drawImageRect(image, srcRect, dstRect, Paint());

      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedImage = await picture.toImage(
        cropWidth,
        cropHeight,
      );
      final ByteData? byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Circle search crop error: $e');
      return null;
    }
  }

  Future<void> _runCircleSearch() async {
    if (!_hasSelection) {
      setState(() {
        _errorText = 'Draw a circle or lasso around something first.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _resultText = null;
      _errorText = null;
    });

    try {
      final Uint8List? croppedBytes = await _cropSelectedRegion();

      if (croppedBytes == null || croppedBytes.isEmpty) {
        throw Exception('Could not crop selected region.');
      }

      final String result = await _freeAiService.circleSearchFromImageBytes(
        croppedBytes,
      );

      if (!mounted) return;

      setState(() {
        _resultText = result.trim().isEmpty
            ? 'No result returned.'
            : result.trim();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Search failed: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _freeAiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.black.withOpacity(0.72),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(color: Colors.transparent),
              ),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.all(18),
                constraints: const BoxConstraints(
                  maxWidth: 1280,
                  maxHeight: 760,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 30,
                      color: Colors.black38,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(cs),
                    Divider(height: 1, color: cs.outlineVariant),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(flex: 7, child: _buildSelectionArea(cs)),
                          Container(width: 1, color: cs.outlineVariant),
                          Expanded(flex: 5, child: _buildResultPanel(cs)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high, color: cs.primary),
          const SizedBox(width: 10),
          const Text(
            'Circle Search',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              'Drag to circle text, diagrams, or objects',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.refresh),
            label: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isSearching ? null : _runCircleSearch,
            icon: _isSearching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_isSearching ? 'Searching...' : 'Search'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Close',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionArea(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (DragStartDetails details) {
                      final RenderBox? box =
                          _imageKey.currentContext?.findRenderObject()
                              as RenderBox?;
                      if (box == null) return;

                      final Offset local = box.globalToLocal(
                        details.globalPosition,
                      );

                      setState(() {
                        _lassoPoints.clear();
                        _lassoPoints.add(local);
                        _resultText = null;
                        _errorText = null;
                      });
                    },
                    onPanUpdate: (DragUpdateDetails details) {
                      final RenderBox? box =
                          _imageKey.currentContext?.findRenderObject()
                              as RenderBox?;
                      if (box == null) return;

                      final Offset local = box.globalToLocal(
                        details.globalPosition,
                      );

                      setState(() {
                        _lassoPoints.add(local);
                      });
                    },
                    child: Stack(
                      children: [
                        Image.memory(
                          widget.previewImageBytes,
                          key: _imageKey,
                          fit: BoxFit.contain,
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _LassoPainter(points: _lassoPoints),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  'Tip: draw a loose circle around the item you want explained.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPanel(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Result',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              'Searches the selected region and returns quick study notes. Right now the backend is a test stub, so it may return a fixed topic until real OCR or vision is added.',
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: _buildResultContent(cs),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (_resultText == null || _resultText!.trim().isEmpty)
                      ? null
                      : () async {
                          await widget.onInsertToBoard(_resultText!);
                        },
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Insert to Board'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSearching ? null : _runCircleSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultContent(ColorScheme cs) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorText != null) {
      return SingleChildScrollView(
        child: Text(
          _errorText!,
          style: TextStyle(color: cs.error, height: 1.5, fontSize: 15),
        ),
      );
    }

    if (_resultText != null && _resultText!.trim().isNotEmpty) {
      return SingleChildScrollView(
        child: SelectableText(
          _resultText!,
          style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.55),
        ),
      );
    }

    return Center(
      child: Text(
        'No result yet.',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
      ),
    );
  }
}

class _LassoPainter extends CustomPainter {
  const _LassoPainter({required this.points});

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);

    for (final Offset p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    final Paint glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint strokePaint = Paint()
      ..color = const Color(0xFF7C4DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _LassoPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
