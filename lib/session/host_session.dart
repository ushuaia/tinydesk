import 'dart:async';

import '../data/host.dart';
import '../session/file_browser_controller.dart';
import '../session/terminal_controller.dart';
import '../core/connection_controller.dart';
import '../core/connection_state.dart';

/// One host's live session: its tunnel/connection and its own terminal.
///
/// Sessions live side by side in [AppSessionManager]. Switching the active
/// host only changes what is displayed — every session's SSH tunnel, web
/// view state and terminal shell stay alive until the session is closed
/// explicitly.
class HostSession {
  HostSession({
    required this.host,
    required this.connection,
    required this.privateKey,
    this.passphrase,
  }) {
    terminals.add(TerminalController(sessionProvider: () => connection.session));
    fileBrowser = FileBrowserController();
  }

  Host host;
  String privateKey;
  String? passphrase;
  final ConnectionController connection;
  final List<TerminalController> terminals = [];
  int activeTerminalIndex = 0;
  late final FileBrowserController fileBrowser;

  /// The shell tab currently shown for this host.
  TerminalController get terminal {
    if (terminals.isEmpty) {
      // Only reachable while a session is being torn down; keep callers safe.
      terminals.add(
        TerminalController(sessionProvider: () => connection.session),
      );
      activeTerminalIndex = 0;
    }
    if (activeTerminalIndex >= terminals.length) {
      activeTerminalIndex = terminals.length - 1;
    }
    return terminals[activeTerminalIndex];
  }

  /// Adds a shell tab and makes it active. The new tab inherits the window
  /// state so switching feels seamless.
  TerminalController addTerminal() {
    final current = terminals.isEmpty ? null : terminal;
    final next = TerminalController(sessionProvider: () => connection.session)
      ..visible = current?.visible ?? true
      ..expanded = current?.expanded ?? true;
    terminals.add(next);
    activeTerminalIndex = terminals.length - 1;
    return next;
  }

  /// Closes one shell tab and disposes it. When the last one closes the
  /// floating terminal disappears with it.
  Future<void> closeTerminalAt(int index) async {
    if (index < 0 || index >= terminals.length) return;
    final removed = terminals.removeAt(index);
    await removed.close();
    removed.dispose();
    if (activeTerminalIndex >= terminals.length) {
      activeTerminalIndex = terminals.length - 1;
    }
    if (activeTerminalIndex < 0) activeTerminalIndex = 0;
  }

  void selectTerminal(int index) {
    if (index < 0 || index >= terminals.length) return;
    if (index == activeTerminalIndex) return;
    final previous = terminal;
    terminals[index]
      ..visible = previous.visible
      ..expanded = previous.expanded;
    activeTerminalIndex = index;
    terminals[index].focusNode.requestFocus();
  }

  ConnectionSnapshot get snapshot => connection.state;

  ConnectionPhase get phase => connection.state.phase;

  bool get isReady => connection.state.phase == ConnectionPhase.ready;

  /// Explicitly closes this session: terminates the shell and disconnects.
  Future<void> close() async {
    for (final controller in terminals.toList()) {
      await controller.close();
    }
    await connection.disconnect();
  }
}
