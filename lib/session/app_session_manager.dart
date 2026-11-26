import 'dart:async';
import '../core/app_language.dart';

import 'package:flutter/widgets.dart';

import '../data/host.dart';
import '../data/host_repository.dart';
import '../data/open_sessions_store.dart';
import '../data/private_key_store.dart';
import '../session/file_browser_controller.dart';
import '../session/terminal_controller.dart';
import '../platform/background_task.dart';
import '../core/connection_controller.dart';
import '../core/connection_state.dart';
import 'host_session.dart';
import 'window_chrome.dart';

/// App-scoped owner of every open host session.
///
/// Unlike the old single-connection design, each host owns a [HostSession]
/// (connection + terminal) that survives host switching and page navigation.
/// Only an explicit [closeSession] tears a session down.
class AppSessionManager extends ChangeNotifier with WidgetsBindingObserver {
  AppSessionManager({
    ConnectionController Function()? connectionFactory,
    this.backgroundTasks = true,
    OpenSessionsStore? openSessionsStore,
  })  : _connectionFactory = connectionFactory ?? ConnectionController.new,
        _store = openSessionsStore ?? OpenSessionsStore() {
    WidgetsBinding.instance.addObserver(this);
  }

  final bool backgroundTasks;
  final ConnectionController Function() _connectionFactory;
  final OpenSessionsStore _store;
  final BackgroundTask _backgroundTask = BackgroundTask();

  final Map<String, HostSession> _sessions = {};
  final List<String> _order = [];
  final Map<String, VoidCallback> _connectionListeners = {};
  final Map<String, VoidCallback> _terminalListeners = {};
  final Map<String, VoidCallback> _fileBrowserListeners = {};

  String? _activeHostId;
  Timer? _backgroundPulse;
  bool _backgroundStarted = false;
  bool _disposed = false;
  bool _restored = false;

  // Lazily created placeholders so legacy getters stay non-null before any
  // session exists (used by tests and the floating terminal ball).
  ConnectionController? _idleConnection;
  TerminalController? _idleTerminal;

  /// Open sessions in the order they were opened.
  List<HostSession> get sessions => [
        for (final id in _order)
          if (_sessions[id] != null) _sessions[id]!,
      ];

  HostSession? get activeSession =>
      _activeHostId == null ? null : _sessions[_activeHostId];

  Host? get activeHost => activeSession?.host;

  bool get isReady => activeSession?.isReady ?? false;

  bool isActiveHost(String hostId) => _activeHostId == hostId;

  bool hasSession(String hostId) => _sessions.containsKey(hostId);

  HostSession? sessionOf(String hostId) => _sessions[hostId];

  ConnectionPhase? phaseOf(String hostId) => _sessions[hostId]?.phase;

  /// Legacy accessor: the active session's connection.
  ConnectionController get connection =>
      activeSession?.connection ?? (_idleConnection ??= ConnectionController());

  /// Legacy accessor: the active session's terminal.
  TerminalController get terminal {
    final session = activeSession;
    if (session != null) return session.terminal;
    final idle = _idleTerminal ??= TerminalController(
      sessionProvider: () => null,
    );
    if (!_idleTerminalListening) {
      _idleTerminalListening = true;
      idle.addListener(_notify);
    }
    return idle;
  }

  bool _idleTerminalListening = false;

  /// The active session's floating file browser, or null when no session is
  /// open. Unlike the terminal there is no idle instance: the ball only
  /// exists after a host is opened.
  FileBrowserController? get fileBrowser => activeSession?.fileBrowser;

  FileBrowserController? fileBrowserOf(String hostId) =>
      _sessions[hostId]?.fileBrowser;

  /// Shows the floating file browser for the active host and collapses the
  /// terminal window: both are full-screen overlays, so only one stays open.
  void showFileBrowser() {
    final session = activeSession;
    if (session == null) return;
    session.terminal.minimize();
    session.fileBrowser.show();
  }

  /// Handles an app-level back gesture: an expanded file browser minimizes
  /// instead of letting the gesture fall through to the workspace.
  bool handleFileBrowserBack() {
    final controller = fileBrowser;
    if (controller == null || !controller.expanded) return false;
    controller.minimize();
    return true;
  }

  /// Cmd+~: cycles through the main page and every open overlay (terminal /
  /// file browser). Returns the stop it moved to, or null when no overlay is
  /// open (the shortcut then does nothing).
  Future<FrontWindow?> cycleOverlay() async {
    final session = activeSession;
    if (session == null) return null;
    final current = frontWindowOf(session.terminal, session.fileBrowser);
    final next = nextOverlayStep(
      terminalOpen: session.terminal.visible,
      browserOpen: session.fileBrowser.visible,
      current: current,
    );
    if (next == null) return null;
    switch (next) {
      case FrontWindow.terminal:
        await showTerminal();
        session.terminal.focusNode.requestFocus();
      case FrontWindow.fileBrowser:
        showFileBrowser();
      case FrontWindow.none:
        switch (current) {
          case FrontWindow.terminal:
            session.terminal.minimize();
          case FrontWindow.fileBrowser:
            session.fileBrowser.minimize();
          case FrontWindow.none:
            break;
        }
    }
    return next;
  }

  /// Shows the terminal for the active host and collapses the file browser.
  Future<void> showTerminal() async {
    final session = activeSession;
    if (session == null) {
      await terminal.show();
      return;
    }
    session.fileBrowser.minimize();
    await session.terminal.show();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Opens (or re-activates) a host session and makes it the active one.
  ///
  /// Existing sessions are never torn down here — this is the multi-session
  /// behaviour: switching hosts keeps every other connection and terminal
  /// alive.
  Future<HostSession> openHost(
    Host host,
    String privateKey, {
    String? passphrase,
    bool connect = true,
    bool persist = true,
  }) async {
    var session = _sessions[host.id];
    if (session == null) {
      session = HostSession(
        host: host,
        connection: _connectionFactory(),
        privateKey: privateKey,
        passphrase: passphrase,
      );
      _sessions[host.id] = session;
      _order.add(host.id);
      final s = session;
      void connectionListener() => _onSessionChanged(s);
      void terminalListener() => _notify();
      void fileBrowserListener() => _notify();
      _connectionListeners[host.id] = connectionListener;
      _terminalListeners[host.id] = terminalListener;
      _fileBrowserListeners[host.id] = fileBrowserListener;
      session.connection.addListener(connectionListener);
      session.terminal.addListener(terminalListener);
      session.fileBrowser.addListener(fileBrowserListener);
    } else {
      session.host = host;
      session.privateKey = privateKey;
      session.passphrase = passphrase;
    }
    _activeHostId = host.id;
    _notify();
    if (persist) await _persist();

    if (connect) {
      final phase = session.connection.state.phase;
      if (phase == ConnectionPhase.idle || phase == ConnectionPhase.failed) {
        unawaited(
          session.connection.connect(
            host,
            privateKey,
            passphrase: passphrase,
          ),
        );
      }
    }
    return session;
  }

  /// Legacy API: connect and wait for the connection attempt to finish.
  Future<void> connect(
    Host host,
    String privateKey, {
    String? passphrase,
  }) async {
    if (_disposed) return;
    final session = await openHost(
      host,
      privateKey,
      passphrase: passphrase,
      connect: false,
    );
    if (session.connection.state.phase == ConnectionPhase.ready) {
      _notify();
      return;
    }
    await session.connection.connect(host, privateKey, passphrase: passphrase);
  }

  void activate(String hostId) {
    if (!_sessions.containsKey(hostId) || _activeHostId == hostId) return;
    _activeHostId = hostId;
    _notify();
    unawaited(_persist());
  }

  Future<void> retry([String? hostId]) async {
    if (_disposed) return;
    final session = hostId == null ? activeSession : _sessions[hostId];
    if (session == null) return;
    await session.connection.connect(
      session.host,
      session.privateKey,
      passphrase: session.passphrase,
    );
  }

  /// Legacy API: disconnect the active session.
  Future<void> disconnect() async {
    final hostId = _activeHostId;
    if (hostId == null) return;
    await closeSession(hostId);
  }

  /// Explicitly closes one host session: kills its terminal shell and
  /// disconnects the tunnel. Other sessions are untouched.
  Future<void> closeSession(String hostId) async {
    if (_disposed) return;
    final index = _order.indexOf(hostId);
    final session = _sessions.remove(hostId);
    _order.remove(hostId);
    if (session == null) return;
    final connectionListener = _connectionListeners.remove(hostId);
    final terminalListener = _terminalListeners.remove(hostId);
    final fileBrowserListener = _fileBrowserListeners.remove(hostId);
    if (connectionListener != null) {
      session.connection.removeListener(connectionListener);
    }
    if (terminalListener != null) {
      session.terminal.removeListener(terminalListener);
    }
    if (fileBrowserListener != null) {
      session.fileBrowser.removeListener(fileBrowserListener);
    }
    await session.close();
    session.terminal.dispose();
    session.fileBrowser.dispose();
    session.connection.dispose();
    if (_activeHostId == hostId) {
      // Stay next to where the tab was: the tab that slid into its slot, or
      // the previous one when the closed tab was last.
      if (_order.isEmpty) {
        _activeHostId = null;
      } else {
        final slot = index < 0 ? _order.length - 1 : index;
        _activeHostId = _order[slot.clamp(0, _order.length - 1)];
      }
    }
    await _syncBackgroundTask();
    _notify();
    await _persist();
  }

  Future<void> openTerminal() async {
    if (_disposed) return;
    final session = activeSession;
    if (session == null || !session.isReady) {
      throw StateError(AppL10n.t.connectionNotReady);
    }
    await session.terminal.show();
  }

  /// Restores the sessions that were open when the app last exited.
  Future<void> restore({
    required HostRepository repository,
    required PrivateKeyStore keyStore,
  }) async {
    if (_disposed || _restored) return;
    _restored = true;
    final saved = await _store.load();
    if (saved.isEmpty) return;

    final hosts = await repository.all();
    final byId = {for (final host in hosts) host.id: host};
    for (final id in saved.hostIds) {
      final host = byId[id];
      if (host == null) continue;
      var key = '';
      String? passphrase;
      if (!host.isLocal) {
        final pair = await keyStore.read(id);
        if (pair == null) continue;
        key = pair.$1;
        passphrase = pair.$2;
      }
      await openHost(host, key, passphrase: passphrase, connect: false, persist: false);
    }
    if (saved.activeHostId != null &&
        _sessions.containsKey(saved.activeHostId)) {
      _activeHostId = saved.activeHostId;
    }
    _notify();
    await _persist();

    // Kick all connections in parallel; each session reports its own state.
    for (final session in sessions) {
      unawaited(
        session.connection.connect(
          session.host,
          session.privateKey,
          passphrase: session.passphrase,
        ),
      );
    }
  }

  Future<void> _persist() async {
    await _store.save(
      OpenSessionsSnapshot(
        hostIds: List.of(_order),
        activeHostId: _activeHostId,
      ),
    );
  }

  void _onSessionChanged(HostSession session) {
    if (_disposed || !_sessions.containsKey(session.host.id)) return;
    if (session.connection.state.phase == ConnectionPhase.ready) {
      unawaited(_ensureBackgroundTask());
      session.terminal.onConnectionReady();
      // The old shell may close slightly after the SSH reconnect completes.
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (!_disposed &&
            _sessions.containsKey(session.host.id) &&
            session.connection.state.phase == ConnectionPhase.ready) {
          session.terminal.onConnectionReady();
        }
      });
    }
    _notify();
  }

  Future<void> _syncBackgroundTask() async {
    if (!backgroundTasks) return;
    if (_sessions.isEmpty) {
      _backgroundPulse?.cancel();
      _backgroundPulse = null;
      if (_backgroundStarted) {
        _backgroundStarted = false;
        try {
          await _backgroundTask.stop();
        } catch (_) {}
      }
      return;
    }
    if (_sessions.values.any((session) => session.isReady)) {
      await _ensureBackgroundTask();
    }
  }

  Future<void> _ensureBackgroundTask({int attempt = 0}) async {
    if (_disposed || !backgroundTasks || _backgroundStarted) return;
    try {
      await _backgroundTask.start();
      _backgroundStarted = true;
      _backgroundPulse?.cancel();
      _backgroundPulse = Timer.periodic(const Duration(minutes: 5), (_) {
        unawaited(
          _backgroundTask.update().catchError((Object error) {
            debugPrint('OCBG update failed: $error');
          }),
        );
      });
    } catch (error) {
      debugPrint('OCBG start failed: $error');
      if (attempt < 2 && !_disposed && _sessions.isNotEmpty) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await _ensureBackgroundTask(attempt: attempt + 1);
      }
    }
  }

  Future<void> _resumeBackgroundTask() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_disposed || _sessions.isEmpty) return;
    if (!_backgroundStarted) {
      await _ensureBackgroundTask();
      return;
    }
    if (_disposed) return;
    try {
      await _backgroundTask.update();
    } catch (error) {
      debugPrint('OCBG resume failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed ||
        state != AppLifecycleState.resumed ||
        _sessions.isEmpty) {
      return;
    }
    unawaited(_resumeBackgroundTask());
    for (final session in sessions) {
      if (session.connection.state.phase == ConnectionPhase.failed ||
          session.connection.state.phase == ConnectionPhase.reconnecting) {
        unawaited(retry(session.host.id));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _backgroundPulse?.cancel();
    for (final session in _sessions.values) {
      final connectionListener = _connectionListeners[session.host.id];
      final terminalListener = _terminalListeners[session.host.id];
      final fileBrowserListener = _fileBrowserListeners[session.host.id];
      if (connectionListener != null) {
        session.connection.removeListener(connectionListener);
      }
      if (terminalListener != null) {
        session.terminal.removeListener(terminalListener);
      }
      if (fileBrowserListener != null) {
        session.fileBrowser.removeListener(fileBrowserListener);
      }
      unawaited(session.connection.disconnect());
      session.terminal.dispose();
      session.fileBrowser.dispose();
      session.connection.dispose();
    }
    _sessions.clear();
    _order.clear();
    _idleTerminal?.dispose();
    _idleConnection?.dispose();
    if (backgroundTasks) {
      unawaited(_backgroundTask.stop().catchError((_) {}));
    }
    super.dispose();
  }
}
