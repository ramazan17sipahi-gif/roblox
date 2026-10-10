/// Prevents two full-screen ad formats from being displayed at the same time.
class FullScreenAdCoordinator {
  FullScreenAdCoordinator._();

  static bool _isShowing = false;

  static bool tryBegin() {
    if (_isShowing) return false;
    _isShowing = true;
    return true;
  }

  static void end() {
    _isShowing = false;
  }
}
