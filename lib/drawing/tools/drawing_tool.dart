import 'dart:ui';

abstract class DrawingTool {
  void onStart(Offset point);
  void onUpdate(Offset point);
  void onEnd();
  void paint(Canvas canvas);
}
