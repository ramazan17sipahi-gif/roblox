/// Indices for the 2D UV canvas tool rail.
abstract final class EditorDrawToolIndex {
  static const int navigate = -1;
  static const int brush = 0;
  static const int fill = 1;
  static const int eraser = 2;
  static const int gradient = 3;
  static const int shape = 4;
  static const int sticker = 5;
  static const int aiTexture = 6;

  /// True when one-finger drawing should capture the canvas (blocks pan).
  static bool capturesPointer(int tool) => tool >= brush && tool <= shape;

  /// True when drag gestures create strokes.
  static bool isDragDrawingTool(int tool) =>
      tool == brush || tool == eraser || tool == shape;
}
