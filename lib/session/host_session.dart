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
    terminal = TerminalController(
      sessionProvider: () => connection.session,
    );
    fileBrowser = FileBrowserController();
  }

  Host host;
  String privateKey;
  String? passphrase;
  final ConnectionController connection;
  late final TerminalController terminal;
  late final FileBrowserController fileBrowser;

  ConnectionSnapshot get snapshot => connection.state;

  ConnectionPhase get phase => connection.state.phase;

  bool get isReady => connection.state.phase == ConnectionPhase.ready;

  /// Explicitly closes this session: terminates the shell and disconnects.
  Future<void> close() async {
    await terminal.close();
    await connection.disconnect();
  }
}
