/// Central command enum for the entire Smart Board
/// UI buttons → commands → drawing engine / app logic
enum BoardCommand {
  // ===== Board lifecycle =====
  newBoard,
  saveBoard,
  exportBoard,
  uploadFile,
  clearBoard,
  exitBoard,
  sessions,
  settings,

  // ===== Live / media =====
  goLive,
  aiPen,
  aiSearch,

  // ===== Drawing tools =====
  pen,
  pencil,
  dotPen,
  eraser,

  // ===== Advanced drawing =====
  shapes,
  tables,
  formula,

  // ===== Editing / navigation =====
  undo,
  redo,
  crop,
  move,
  spotlight,

  // ===== Appearance =====
  colorPicker,
  openRepository,

  // ===== Content =====
  books,
  simulations,
  models3D,

  // ===== Live / media =====
  aiLesson,
  aiQuiz,
  aiImageSearch,
  aiVideoSearch,
}
