import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'ai/ai_config.dart';
import 'ai/ai_search_modal.dart';
import 'ai/image_search_modal.dart';
import 'ai/lesson_modal.dart';
import 'ai/quiz_modal.dart';
import 'ai/video_search_modal.dart';
import 'ai_floating_tool/ai_floating_pencil.dart';
import 'board_command.dart';
import 'canvas/canvas_board_widget.dart';
import 'canvas/canvas_manager.dart';
import 'canvas/color_picker_modal.dart';
import 'canvas/drawables.dart';
import 'canvas/drawing_integration.dart';
import 'canvas/eraser_radius_selector.dart';
import 'canvas/formula_panel.dart';
import 'canvas/shape_selector_modal.dart';
import 'canvas/stroke_width_selector.dart';
import 'file_repository.dart';
import 'file_system/file_controller.dart';
import 'repository/file_repository_modal.dart';
import 'repository/session_manager_modal.dart';
import 'repository/upload_modal.dart';
import 'settings/app_settings.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_store.dart';
import 'sketchfab_modal.dart';
import 'storage/export_service.dart';
import 'storage/file_cache.dart';
import 'storage/session_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isAndroid) {
    AndroidWebViewController.enableDebugging(true);
  }

  runApp(const AISmartBoardApp());
}

/* ===================== APP ===================== */

class AISmartBoardApp extends StatelessWidget {
  const AISmartBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final c = SettingsController(SettingsStore());
        c.load();
        return c;
      },
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    const seed = Color(0xFF7C4DFF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: const BoardScreen(),
    );
  }
}

/* ===================== BOARD SCREEN ===================== */

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  BoardCommand? activeTool;
  bool showFormulaPanel = false;
  ShapeType selectedShape = ShapeType.rectangle;
  Color selectedShapeColor = Colors.black;
  DrawingIntegration? drawingIntegration;

  bool _settingsOpen = false;
  bool _showCircleSearchPanel = false;
  bool _showToolOverlay = false;

  void _openSettings() => setState(() => _settingsOpen = true);
  void _closeSettings() => setState(() => _settingsOpen = false);

  late final CanvasManager canvasVm = CanvasManager();

  late final FileController fileCtrl = FileController(
    cache: FileCache(),
    sessions: SessionStorage(),
  );

  final ExportService exportService = ExportService();

  Size _boardSize = Size.zero;

  @override
  void initState() {
    super.initState();
    fileCtrl.init();
  }

  @override
  void dispose() {
    fileCtrl.dispose();
    canvasVm.dispose();
    super.dispose();
  }

  void _enterCircleSearchMode() {
    setState(() {
      activeTool = BoardCommand.aiPen;
      showFormulaPanel = false;
      _showCircleSearchPanel = false;
      _showToolOverlay = false;
    });

    canvasVm.setMode(EditMode.circleSearch);
    canvasVm.clearCircleSearchSelection();
  }

  void _exitCircleSearchMode() {
    setState(() {
      if (activeTool == BoardCommand.aiPen) {
        activeTool = null;
      }
      _showCircleSearchPanel = false;
      _showToolOverlay = false;
    });

    canvasVm.clearCircleSearchSelection();
    canvasVm.setMode(EditMode.draw);
  }

  Future<void> _runSameBoardCircleSearch() async {
    if (_boardSize == Size.zero) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Board size not ready yet')));
      return;
    }

    try {
      await canvasVm.runCircleSearch(_boardSize);
      if (!mounted) return;

      setState(() {
        _showCircleSearchPanel = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Circle Search failed: $e')));
    }
  }

  Future<void> _insertTextToBoard(String text) async {
    final board = _boardSize;
    if (board == Size.zero) return;

    final pos = Offset(board.width * 0.18, board.height * 0.18);

    final item = TextItem(
      id: 'txt_${DateTime.now().millisecondsSinceEpoch}',
      zIndex: canvasVm.nextZ(),
      text: text,
      position: pos,
      fontSize: 18,
      color: Colors.black,
      maxWidth: board.width * 0.55,
      padding: 12,
      drawBackground: true,
    );

    canvasVm.addItem(item);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Inserted to board ✅')));
  }

  /* ===================== COMMAND HANDLER ===================== */

  Future<void> executeCommand(BoardCommand command) async {
    debugPrint('Command executed: $command');

    if (command != BoardCommand.aiPen &&
        command != BoardCommand.aiSearch &&
        command != BoardCommand.aiImageSearch &&
        command != BoardCommand.aiLesson &&
        command != BoardCommand.aiQuiz &&
        command != BoardCommand.aiVideoSearch) {
      if (activeTool == BoardCommand.aiPen) {
        _exitCircleSearchMode();
      }
    }

    if (command == BoardCommand.aiVideoSearch) {
      await showVideoSearchModal(context);
      return;
    }

    if (command == BoardCommand.aiLesson) {
      await showLessonModal(context: context, baseUrl: AIConfig.baseUrl);
      return;
    }

    if (command == BoardCommand.aiQuiz) {
      await showQuizModal(context: context, baseUrl: AIConfig.baseUrl);
      return;
    }

    if (command == BoardCommand.aiSearch) {
      await showAiSearchModal(
        context,
        onInsertToBoard: (text) => _insertTextToBoard(text),
      );
      return;
    }

    if (command == BoardCommand.aiPen) {
      _enterCircleSearchMode();
      return;
    }

    if (command == BoardCommand.aiImageSearch) {
      await showImageSearchModal(
        context,
        onInsertToBoard: (url) async {
          try {
            if (!mounted) return;

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Inserting image...')));

            final res = await http.get(Uri.parse(url));
            if (res.statusCode != 200) {
              throw Exception('Failed: ${res.statusCode}');
            }

            final bytes = res.bodyBytes;
            final b64 = base64Encode(bytes);

            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            final img = frame.image;

            final board = _boardSize;
            final maxW = board.width * 0.45;
            final maxH = board.height * 0.45;

            final iw = img.width.toDouble();
            final ih = img.height.toDouble();
            final s1 = (maxW / iw).clamp(0.0, double.infinity);
            final s2 = (maxH / ih).clamp(0.0, double.infinity);
            final s = s1 < s2 ? s1 : s2;

            final w = iw * s;
            final h = ih * s;

            final cx = board.width / 2;
            final cy = board.height / 2;

            final rect = Rect.fromCenter(
              center: Offset(cx, cy),
              width: w,
              height: h,
            );

            final item = ImageItem(
              id: 'img_${DateTime.now().millisecondsSinceEpoch}',
              zIndex: canvasVm.nextZ(),
              rect: rect,
              imageBytesB64: b64,
            );

            await item.ensureDecoded();
            canvasVm.addItem(item);

            if (!mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Image inserted ✅')));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Insert failed: $e')));
          }
        },
      );
      return;
    }

    if (command == BoardCommand.settings) {
      _openSettings();
      return;
    }

    const selectableTools = {
      BoardCommand.pen,
      BoardCommand.pencil,
      BoardCommand.dotPen,
      BoardCommand.eraser,
      BoardCommand.shapes,
      BoardCommand.tables,
      BoardCommand.formula,
      BoardCommand.colorPicker,
      BoardCommand.crop,
      BoardCommand.move,
      BoardCommand.spotlight,
    };

    if (selectableTools.contains(command)) {
      setState(() {
        activeTool = command;
        _showToolOverlay = _isDrawingTool(command);
        showFormulaPanel = command == BoardCommand.formula;
      });

      if (command == BoardCommand.crop) {
        canvasVm.setMode(EditMode.crop);
      } else if (command == BoardCommand.move) {
        canvasVm.setMode(EditMode.move);
      } else if (command == BoardCommand.spotlight) {
        canvasVm.setMode(EditMode.spotlight);
      } else {
        canvasVm.setMode(EditMode.draw);
      }

      if (command == BoardCommand.colorPicker) {
        final newColor = await showColorPickerModal(context, canvasVm.color);
        if (newColor != null) {
          canvasVm.setColor(newColor);
        }
        setState(() {
          _showToolOverlay = false;
        });
      }

      if (command == BoardCommand.shapes) {
        final shapeConfig = await showShapeSelector(
          context,
          selectedShape,
          selectedShapeColor,
        );
        if (shapeConfig != null) {
          setState(() {
            selectedShape = shapeConfig.shape;
            selectedShapeColor = shapeConfig.color;
            _showToolOverlay = false;
          });
          drawingIntegration?.setSelectedShape(shapeConfig.shape);
          drawingIntegration?.setSelectedShapeColor(shapeConfig.color);
        }
      }

      return;
    }

    if (command == BoardCommand.uploadFile) {
      await showUploadModal(context, fileCtrl);
      return;
    }

    if (command == BoardCommand.openRepository) {
      await showFileRepositoryModal(context, fileCtrl);
      return;
    }

    if (command == BoardCommand.sessions) {
      await showSessionManagerModal(
        context,
        loader: fileCtrl.listSessions,
        onLoad: (id) async {
          final payload = await fileCtrl.loadSession(id);
          if (payload == null) return;

          canvasVm.loadFromJson(jsonDecode(payload.boardJsonString));

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Session loaded')));
          }
        },
        onDelete: fileCtrl.deleteSession,
      );
      return;
    }

    if (command == BoardCommand.models3D) {
      final selectedModel = await Navigator.of(context).push<Map>(
        MaterialPageRoute(
          builder: (context) => const SketchfabModal(),
          fullscreenDialog: true,
        ),
      );

      if (selectedModel != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected: ${selectedModel["name"] ?? "3D Model"}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (command == BoardCommand.books) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FileRepository(
            onClose: () => Navigator.of(context).pop(),
            onOpenInBoard: (url) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening file: $url'),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
          fullscreenDialog: true,
        ),
      );
      return;
    }

    if (command == BoardCommand.saveBoard) {
      final boardJson = canvasVm.toJsonString();
      final thumbnailBytes = await canvasVm.exportPngBytes(
        _boardSize,
        pixelRatio: 1.0,
      );

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await fileCtrl.saveSession(
        sessionId: sessionId,
        sessionName:
            'Board ${DateTime.now().toLocal().toString().split('.')[0]}',
        boardJsonString: boardJson,
        thumbnailPng: thumbnailBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Board saved successfully')),
        );
      }
      return;
    }

    if (command == BoardCommand.exportBoard) {
      if (_boardSize == Size.zero) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Board size not ready. Try again.')),
        );
        return;
      }

      final bytes = await canvasVm.exportPngBytes(_boardSize, pixelRatio: 2.0);
      final savedPath = await exportService.savePngBytes(bytes);

      await Share.shareXFiles([
        XFile(savedPath),
      ], text: 'AI Smart Board Export');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported: $savedPath')));
      }
      return;
    }

    if (command == BoardCommand.undo) {
      canvasVm.undo();
      return;
    }

    if (command == BoardCommand.redo) {
      canvasVm.redo();
      return;
    }

    if (command == BoardCommand.clearBoard) {
      canvasVm.clearCanvas();
      return;
    }

    if (command == BoardCommand.newBoard) {
      canvasVm.newBoard();
      return;
    }
  }

  /* ===================== UI ===================== */

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _topBar(),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _sideBar(left: true),
                _canvas(),
                _sideBar(left: false),
              ],
            ),
          ),
          _bottomTools(),
        ],
      ),
    );
  }

  AppBar _topBar() {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      elevation: 1,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      centerTitle: true,
      title: const Text(
        'AI Smart Board',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      leadingWidth: 160,
      leading: Padding(
        padding: const EdgeInsets.all(6),
        child: OutlinedButton.icon(
          onPressed: () => executeCommand(BoardCommand.newBoard),
          icon: const Icon(Icons.add),
          label: const Text('New Board'),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.error,
            side: BorderSide(color: cs.error),
          ),
          child: const Text('● LIVE'),
        ),
        const SizedBox(width: 12),
        IconButton(onPressed: () {}, icon: const Icon(Icons.videocam)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.person)),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _sideBar({required bool left}) {
    final cs = Theme.of(context).colorScheme;

    final items = left
        ? [
            _sideIcon(Icons.save, 'Save', BoardCommand.saveBoard),
            _sideIcon(Icons.download, 'Export', BoardCommand.exportBoard),
            _sideIcon(Icons.upload, 'Upload', BoardCommand.uploadFile),
            _sideIcon(Icons.settings, 'Settings', BoardCommand.settings),
            _sideIcon(Icons.list, 'Sessions', BoardCommand.sessions),
          ]
        : [
            _sideIcon(Icons.undo, 'Undo', BoardCommand.undo),
            _sideIcon(Icons.redo, 'Redo', BoardCommand.redo),
            _sideIcon(Icons.delete, 'Clear', BoardCommand.clearBoard),
            _sideIcon(
              Icons.exit_to_app,
              'Exit',
              BoardCommand.exitBoard,
              color: cs.error,
            ),
          ];

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: left ? BorderSide(color: cs.outlineVariant) : BorderSide.none,
          left: !left ? BorderSide(color: cs.outlineVariant) : BorderSide.none,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items,
      ),
    );
  }

  Widget _canvas() {
    final cs = Theme.of(context).colorScheme;
    final s = context.watch<SettingsController>().settings;

    return Expanded(
      child: LayoutBuilder(
        builder: (_, constraints) {
          _boardSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Container(
            color: cs.surfaceContainerLowest,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BoardBackgroundPainter(
                      background: s.canvasBackground,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CanvasBoardWidget(
                    vm: canvasVm,
                    activeTool: activeTool,
                    selectedShape: selectedShape,
                    onDrawingIntegrationReady: (integration) {
                      drawingIntegration = integration;
                      integration.setSelectedShape(selectedShape);
                      integration.setSelectedShapeColor(selectedShapeColor);
                    },
                  ),
                ),

                if (_showCircleSearchPanel) _circleSearchCard(canvasVm, cs),

                if (showFormulaPanel)
                  Positioned(
                    right: 16,
                    top: 80,
                    child: FormulaPanel(
                      canvasManager: canvasVm,
                      onSymbolSelected: () {
                        setState(() {
                          showFormulaPanel = false;
                          activeTool = null;
                        });
                      },
                    ),
                  ),

                if (_showToolOverlay &&
                    activeTool != null &&
                    _isDrawingTool(activeTool!))
                  Positioned(
                    left: 16,
                    top: 80,
                    child: activeTool == BoardCommand.eraser
                        ? EraserRadiusSelector(
                            currentRadius:
                                drawingIntegration?.eraserRadius ?? 22.0,
                            onRadiusChanged: (radius) {
                              drawingIntegration?.setEraserRadius(radius);
                              setState(() {
                                _showToolOverlay = false;
                              });
                            },
                          )
                        : StrokeWidthSelector(
                            currentWidth: canvasVm.strokeWidth,
                            currentColor: canvasVm.color,
                            onWidthChanged: (width) {
                              canvasVm.setStrokeWidth(width);
                            },
                            onColorChanged: (color) {
                              canvasVm.setColor(color);
                            },
                            onApply: () {
                              setState(() {
                                _showToolOverlay = false;
                              });
                            },
                          ),
                  ),

                if (!_showToolOverlay &&
                    activeTool != null &&
                    _isDrawingTool(activeTool!))
                  Positioned(
                    left: 22,
                    top: 210,
                    child: Material(
                      elevation: 8,
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showToolOverlay = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 12,
                                color: Colors.black26,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: canvasVm.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (activeTool == BoardCommand.aiPen && !_showCircleSearchPanel)
                  Positioned(
                    right: 20,
                    top: 20,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(16),
                      color: cs.surface,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.icon(
                              onPressed: canvasVm.isCircleSearchLoading
                                  ? null
                                  : _runSameBoardCircleSearch,
                              icon: canvasVm.isCircleSearchLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(
                                canvasVm.isCircleSearchLoading
                                    ? 'Searching...'
                                    : 'Search',
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                canvasVm.clearCircleSearchSelection();
                              },
                              child: const Text('Clear'),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _exitCircleSearchMode,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                AIFloatingPencil(
                  onCommand: (command) async {
                    await executeCommand(command);
                  },
                ),

                if (_settingsOpen) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeSettings,
                      child: Container(color: Colors.black.withOpacity(0.25)),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: SettingsDrawer(onClose: _closeSettings),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _circleSearchCard(CanvasManager canvasVm, ColorScheme cs) {
    return Positioned(
      right: 20,
      top: 80,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(16),
          child: AnimatedBuilder(
            animation: canvasVm,
            builder: (_, __) {
              return SizedBox(
                height: 430,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Circle Search",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            canvasVm.circleSearchError ??
                                canvasVm.circleSearchResult ??
                                'Circle something on the board and press Search.',
                            style: TextStyle(
                              color: canvasVm.circleSearchError != null
                                  ? cs.error
                                  : cs.onSurface,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: canvasVm.isCircleSearchLoading
                                ? null
                                : _runSameBoardCircleSearch,
                            icon: const Icon(Icons.search),
                            label: const Text("Search"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                (canvasVm.circleSearchResult == null ||
                                    canvasVm.circleSearchResult!.trim().isEmpty)
                                ? null
                                : () async {
                                    await _insertTextToBoard(
                                      canvasVm.circleSearchResult!,
                                    );
                                  },
                            icon: const Icon(Icons.note_add_outlined),
                            label: const Text("Insert to Board"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          canvasVm.clearCircleSearchSelection();
                          setState(() {
                            _showCircleSearchPanel = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bottomTools() {
    final cs = Theme.of(context).colorScheme;
    final s = context.watch<SettingsController>().settings;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        color: cs.surface,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (s.showPen) _tool(Icons.edit, 'Pen', BoardCommand.pen),
                  if (s.showPencil)
                    _tool(Icons.star_border, 'Pencil', BoardCommand.pencil),
                  if (s.showEraser)
                    _tool(
                      Icons.cleaning_services,
                      'Eraser',
                      BoardCommand.eraser,
                    ),
                  if (s.showShapes)
                    _tool(Icons.category, 'Shapes', BoardCommand.shapes),
                  if (s.showColour)
                    _tool(Icons.palette, 'Colour', BoardCommand.colorPicker),
                  if (s.showFormula)
                    _tool(Icons.functions, 'Formula', BoardCommand.formula),
                  if (s.showDotPen)
                    _tool(
                      Icons.circle_outlined,
                      'Dot Pen',
                      BoardCommand.dotPen,
                    ),
                  if (s.showTables)
                    _tool(Icons.table_chart, 'Tables', BoardCommand.tables),
                  if (s.showCrop) _tool(Icons.crop, 'Crop', BoardCommand.crop),
                  if (s.showMove)
                    _tool(Icons.open_with, 'Move', BoardCommand.move),
                  if (s.showSpotlight)
                    _tool(
                      Icons.my_location,
                      'Spotlight',
                      BoardCommand.spotlight,
                    ),
                  if (s.showFiles)
                    _tool(Icons.folder, 'Files', BoardCommand.openRepository),
                ],
              ),
            ),
          ),
          _divider(),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _compactTool(Icons.auto_fix_high, 'AI Pen', BoardCommand.aiPen),
                _compactTool(Icons.search, 'AI Search', BoardCommand.aiSearch),
              ],
            ),
          ),
          _divider(),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _compactTool(Icons.menu_book, 'Books', BoardCommand.books),
                _compactTool(
                  Icons.videocam,
                  'Simulations',
                  BoardCommand.simulations,
                ),
                _compactTool(
                  Icons.view_in_ar,
                  '3D Models',
                  BoardCommand.models3D,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isDrawingTool(BoardCommand command) {
    return [
      BoardCommand.pen,
      BoardCommand.pencil,
      BoardCommand.dotPen,
      BoardCommand.eraser,
      BoardCommand.shapes,
      BoardCommand.tables,
    ].contains(command);
  }

  Widget _sideIcon(
    IconData icon,
    String label,
    BoardCommand command, {
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;

    return InkWell(
      onTap: () => executeCommand(command),
      child: Column(
        children: [
          Icon(icon, color: c),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: c.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String label, BoardCommand command) {
    final cs = Theme.of(context).colorScheme;
    final isActive = activeTool == command;

    final activeColor = cs.primary;
    final normalColor = cs.onSurface;

    return InkWell(
      onTap: () => executeCommand(command),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 96,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: isActive ? activeColor : normalColor),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? activeColor : normalColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactTool(IconData icon, String label, BoardCommand command) {
    final cs = Theme.of(context).colorScheme;

    final bool isActive = command == BoardCommand.aiPen
        ? activeTool == BoardCommand.aiPen
        : activeTool == command;

    final activeColor = cs.primary;
    final normalColor = cs.onSurface;

    return Expanded(
      child: InkWell(
        onTap: () => executeCommand(command),
        child: Container(
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: isActive ? activeColor : normalColor),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? activeColor : normalColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: double.infinity,
      color: cs.outlineVariant,
    );
  }
}

/* ===================== SETTINGS DRAWER ===================== */

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final s = ctrl.settings;
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 16,
      color: cs.surface,
      child: SizedBox(
        width: 380,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  _sectionTitle(context, 'Appearance'),
                  _card(
                    context,
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      secondary: const Icon(Icons.dark_mode),
                      title: const Text('Dark mode'),
                      value: s.darkMode,
                      onChanged: (v) => ctrl.setDarkMode(v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle(context, 'Canvas'),
                  _card(
                    context,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: DropdownButtonFormField<CanvasBackground>(
                        value: s.canvasBackground,
                        decoration: const InputDecoration(
                          labelText: 'Background',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: CanvasBackground.values.map((bg) {
                          final label = switch (bg) {
                            CanvasBackground.plain => 'Plain',
                            CanvasBackground.grid => 'Grid',
                            CanvasBackground.lined => 'Lined',
                          };
                          return DropdownMenuItem(
                            value: bg,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) ctrl.setCanvasBackground(v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle(context, 'AI Image Search'),
                  _card(
                    context,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.image_search),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Image search results',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text('${s.imageResultCount}'),
                            ],
                          ),
                          Slider(
                            value: s.imageResultCount.toDouble(),
                            min: 5,
                            max: 30,
                            divisions: 5,
                            label: '${s.imageResultCount}',
                            onChanged: (v) =>
                                ctrl.setImageResultCount(v.round()),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Auto-insert to board'),
                            subtitle: const Text(
                              'Tap an image to place it directly',
                            ),
                            value: s.imageAutoInsert,
                            onChanged: (v) => ctrl.setImageAutoInsert(v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle(context, 'Sessions'),
                  _card(
                    context,
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      secondary: const Icon(Icons.save),
                      title: const Text('Auto-save sessions'),
                      subtitle: const Text('Saves board state periodically'),
                      value: s.autoSaveCanvas,
                      onChanged: (v) => ctrl.setAutoSaveCanvas(v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle(context, 'Toolbar'),
                  _card(
                    context,
                    child: Column(
                      children: [
                        _toolSwitch('Pen', s.showPen, ctrl.setShowPen),
                        _toolSwitch('Pencil', s.showPencil, ctrl.setShowPencil),
                        _toolSwitch('Eraser', s.showEraser, ctrl.setShowEraser),
                        _toolSwitch('Shapes', s.showShapes, ctrl.setShowShapes),
                        _toolSwitch('Colour', s.showColour, ctrl.setShowColour),
                        _toolSwitch(
                          'Formula',
                          s.showFormula,
                          ctrl.setShowFormula,
                        ),
                        _toolSwitch(
                          'Dot Pen',
                          s.showDotPen,
                          ctrl.setShowDotPen,
                        ),
                        _toolSwitch('Tables', s.showTables, ctrl.setShowTables),
                        _toolSwitch('Crop', s.showCrop, ctrl.setShowCrop),
                        _toolSwitch('Move', s.showMove, ctrl.setShowMove),
                        _toolSwitch(
                          'Spotlight',
                          s.showSpotlight,
                          ctrl.setShowSpotlight,
                        ),
                        _toolSwitch('Files', s.showFiles, ctrl.setShowFiles),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ctrl.resetToDefaults();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings reset')),
                        );
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onClose,
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  static Widget _card(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }

  static Widget _toolSwitch(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

/* ===================== CANVAS BACKGROUND PAINTER ===================== */

class _BoardBackgroundPainter extends CustomPainter {
  _BoardBackgroundPainter({required this.background, required this.isDark});

  final CanvasBackground background;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = isDark ? const Color(0xFF121216) : const Color(0xFFFBF7FD);
    canvas.drawRect(Offset.zero & size, base);

    if (background == CanvasBackground.plain) return;

    final line = Paint()
      ..color = isDark ? const Color(0x22FFFFFF) : const Color(0x22000000)
      ..strokeWidth = 1;

    if (background == CanvasBackground.lined) {
      const gap = 36.0;
      for (double y = gap; y < size.height; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
      return;
    }

    if (background == CanvasBackground.grid) {
      const gap = 40.0;
      for (double x = gap; x < size.width; x += gap) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      }
      for (double y = gap; y < size.height; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardBackgroundPainter oldDelegate) {
    return oldDelegate.background != background || oldDelegate.isDark != isDark;
  }
}
