import 'file_browser_controller.dart';
import 'terminal_controller.dart';

/// The overlay window that is actually on screen.
///
/// A minimized overlay (the floating ball) is still `visible`, so it must not
/// count here: the traffic-light actions always target the window the user can
/// see, never a ball.
enum FrontWindow { none, terminal, fileBrowser }

/// The terminal is drawn above the file browser, so it wins when both are open.
FrontWindow frontWindowOf(
  TerminalController? terminal,
  FileBrowserController? fileBrowser,
) {
  if (terminal != null && terminal.visible && terminal.expanded) {
    return FrontWindow.terminal;
  }
  if (fileBrowser != null && fileBrowser.visible && fileBrowser.expanded) {
    return FrontWindow.fileBrowser;
  }
  return FrontWindow.none;
}
