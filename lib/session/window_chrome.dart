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

/// Next stop when cycling overlays with Cmd+~.
///
/// Only overlays that are still open (expanded or collapsed to a ball) take
/// part, so the cycle has exactly as many stops as the user has open:
/// [main page] + terminal? + file browser?. Returns `null` when nothing is
/// open, in which case the shortcut does nothing.
FrontWindow? nextOverlayStep({
  required bool terminalOpen,
  required bool browserOpen,
  required FrontWindow current,
}) {
  final stops = <FrontWindow>[
    FrontWindow.none,
    if (terminalOpen) FrontWindow.terminal,
    if (browserOpen) FrontWindow.fileBrowser,
  ];
  if (stops.length == 1) return null;
  final index = stops.indexOf(current);
  return stops[(index + 1) % stops.length];
}
