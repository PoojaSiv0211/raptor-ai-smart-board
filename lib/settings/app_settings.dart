// lib/settings/app_settings.dart

enum CanvasBackground { plain, grid, lined }

enum ImageQuality { thumbnail, high }

class AppSettings {
  AppSettings({
    this.defaultGrade = 8,
    this.quizLength = 5,
    this.darkMode = false,
    this.canvasBackground = CanvasBackground.plain,
    this.penThickness = 3.0,
    this.imageQuality = ImageQuality.thumbnail,
    this.imageAutoInsert = false,
    this.imageResultCount = 20,
    this.autoSaveCanvas = true,

    // ===== Bottom toolbar visibility toggles (MVP) =====
    this.showPen = true,
    this.showPencil = true,
    this.showEraser = true,
    this.showShapes = true,
    this.showColour = true,
    this.showFormula = true,
    this.showDotPen = true,
    this.showTables = true,
    this.showCrop = true,
    this.showMove = true,
    this.showSpotlight = true,
    this.showFiles = true,
  });

  int defaultGrade;
  int quizLength;

  bool darkMode;
  CanvasBackground canvasBackground;
  double penThickness;

  ImageQuality imageQuality;
  bool imageAutoInsert;
  int imageResultCount;

  bool autoSaveCanvas;

  // ===== Bottom toolbar visibility toggles (MVP) =====
  bool showPen;
  bool showPencil;
  bool showEraser;
  bool showShapes;
  bool showColour;
  bool showFormula;
  bool showDotPen;
  bool showTables;
  bool showCrop;
  bool showMove;
  bool showSpotlight;
  bool showFiles;

  Map<String, dynamic> toMap() => {
    "defaultGrade": defaultGrade,
    "quizLength": quizLength,
    "darkMode": darkMode,
    "canvasBackground": canvasBackground.index,
    "penThickness": penThickness,
    "imageQuality": imageQuality.index,
    "imageAutoInsert": imageAutoInsert,
    "imageResultCount": imageResultCount,
    "autoSaveCanvas": autoSaveCanvas,

    // toolbar toggles
    "showPen": showPen,
    "showPencil": showPencil,
    "showEraser": showEraser,
    "showShapes": showShapes,
    "showColour": showColour,
    "showFormula": showFormula,
    "showDotPen": showDotPen,
    "showTables": showTables,
    "showCrop": showCrop,
    "showMove": showMove,
    "showSpotlight": showSpotlight,
    "showFiles": showFiles,
  };

  static AppSettings fromMap(Map<String, dynamic> m) => AppSettings(
    defaultGrade: (m["defaultGrade"] ?? 8) as int,
    quizLength: (m["quizLength"] ?? 5) as int,
    darkMode: (m["darkMode"] ?? false) as bool,
    canvasBackground:
        CanvasBackground.values[(m["canvasBackground"] ?? 0) as int],
    penThickness: (m["penThickness"] ?? 3.0).toDouble(),
    imageQuality: ImageQuality.values[(m["imageQuality"] ?? 0) as int],
    imageAutoInsert: (m["imageAutoInsert"] ?? false) as bool,
    imageResultCount: (m["imageResultCount"] ?? 20) as int,
    autoSaveCanvas: (m["autoSaveCanvas"] ?? true) as bool,

    // toolbar toggles (defaults true)
    showPen: (m["showPen"] ?? true) as bool,
    showPencil: (m["showPencil"] ?? true) as bool,
    showEraser: (m["showEraser"] ?? true) as bool,
    showShapes: (m["showShapes"] ?? true) as bool,
    showColour: (m["showColour"] ?? true) as bool,
    showFormula: (m["showFormula"] ?? true) as bool,
    showDotPen: (m["showDotPen"] ?? true) as bool,
    showTables: (m["showTables"] ?? true) as bool,
    showCrop: (m["showCrop"] ?? true) as bool,
    showMove: (m["showMove"] ?? true) as bool,
    showSpotlight: (m["showSpotlight"] ?? true) as bool,
    showFiles: (m["showFiles"] ?? true) as bool,
  );
}
