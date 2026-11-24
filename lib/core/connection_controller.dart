import 'dart:async';

import '../core/app_language.dart';

import 'package:flutter/foundation.dart';

import '../data/host.dart';
import '../opencode/opencode_client.dart';
import '../opencode/opencode_errors.dart';
import '../ssh/ssh_connector.dart';
import '../ssh/ssh_errors.dart';
import '../ssh/tunnel_session.dart';
import '../data/local_session.dart';
import 'connection_state.dart';

class Backoff {
  Duration next(int attempt) {
    final seconds = [1, 2, 4, 8, 15, 30][attempt.clamp(0, 5).toInt()];
    return Duration(seconds: seconds);
  }
}

class ConnectionController extends ValueNotifier<ConnectionSnapshot> {
  ConnectionController({
    TunnelOpener? opener,
    Backoff? backoff,
    this.connectTimeout = const Duration(seconds: 90),
    this.keepAliveInterval = const Duration(seconds: 30),
    this.keepAliveTimeout = const Duration(seconds: 20),
  })  : _opener = opener ?? openSshTunnel,
        _backoff = backoff ?? Backoff(),
        super(const ConnectionSnapshot(phase: ConnectionPhase.idle));

  static const _maxRetries = 5;

  final Duration connectTimeout;
  final Duration keepAliveInterval;
  final Duration keepAliveTimeout;

  final TunnelOpener _opener;
  final Backoff _backoff;
  bool _keepAliveBusy = false;

  TunnelSession? _session;
  Timer? _keepAliveTimer;
  bool _manualDisconnect = false;
  bool _connecting = false;
  bool _disposed = false;
  int _attempt = 0;

  Host? _host;
  String? _privateKey;
  String? _passphrase;
  UnknownHostKeyHandler? _onUnknownHostKey;
  HostKeyChangedHandler? _onHostKeyChanged;

  ConnectionSnapshot get state => value;

  TunnelSession? get session => _session;

  set state(ConnectionSnapshot snapshot) {
    if (_disposed) return;
    value = snapshot;
  }

  @override
  void dispose() {
    _disposed = true;
    _keepAliveTimer?.cancel();
    super.dispose();
  }

  Future<void> connect(
    Host host,
    String privateKey, {
    String? passphrase,
    UnknownHostKeyHandler? onUnknownHostKey,
    HostKeyChangedHandler? onHostKeyChanged,
    int attempt = 0,
  }) async {
    if (_connecting) return;
    _connecting = true;
    _manualDisconnect = false;
    _attempt = attempt;
    _host = host;
    _privateKey = privateKey;
    _passphrase = passphrase;
    _onUnknownHostKey = onUnknownHostKey;
    _onHostKeyChanged = onHostKeyChanged;

    await _closeSession();

    try {
      _set(host.isLocal ? ConnectionPhase.tunneling : ConnectionPhase.sshConnecting);

      final Future<TunnelSession> opening = host.isLocal
          ? LocalSession.open(host)
          : _opener(
              host,
              privateKey,
              passphrase,
              onUnknownHostKey ?? (_) async => true,
              onHostKeyChanged ?? (_, _) async => false,
            );
      final TunnelSession session = await _withDeadline(opening);
      _session = session;
      unawaited(session.closed.then((_) => _handleClosed(session)));

      _set(ConnectionPhase.tunneling);
      _set(ConnectionPhase.probing);

      final baseUrl = 'http://127.0.0.1:${host.localPort}';
      var status = await session.probe(baseUrl);

      if (status == ServerStatus.offline && host.autoStartServer) {
        _set(ConnectionPhase.startingServer);
        await _withDeadline(session.startService());
        status = await session.probe(baseUrl);
      }

      if (status == ServerStatus.offline) {
        debugPrint('connect: probe offline for ${host.name} ($baseUrl)');
        throw ServerUnreachable(AppL10n.t.remoteOpencodeUnreachable);
      }
      debugPrint('connect: probe ok for ${host.name}');

      // No pairing here: the workspace keeps the WebView session cookie and
      // only asks for a one-time link when the page is not authenticated
      // yet. Skipping it saves an SSH round-trip on every connect.
      _attempt = 0;
      state = state.copyWith(phase: ConnectionPhase.ready);
      _startKeepAlive();
    } on SshError catch (error) {
      debugPrint('connect failed (ssh): ${error.userMessage}');
      _fail(error.userMessage);
    } on OpencodeError catch (error) {
      debugPrint('connect failed (opencode): ${error.userMessage}');
      _fail(error.userMessage);
    } catch (error) {
      debugPrint('connect failed: $error');
      _fail(AppL10n.t.connectionFailed(error.toString()));
    } finally {
      _connecting = false;
    }
  }

  void _fail(String message) {
    if (_manualDisconnect) return;
    unawaited(_closeSession());
    if (_attempt > 0 && _attempt < _maxRetries) {
      _scheduleRetry(message);
      return;
    }
    state = ConnectionSnapshot(
      phase: ConnectionPhase.failed,
      message: message,
    );
  }

  void _scheduleRetry([String? message]) {
    if (_manualDisconnect || _host == null || _privateKey == null) return;
    final delay = _backoff.next(_attempt);
    final nextAttempt = _attempt + 1;
    state = ConnectionSnapshot(
      phase: ConnectionPhase.reconnecting,
      message: message == null ? AppL10n.t.disconnectedReconnecting : AppL10n.t.reconnectingWith(message),
    );
    Future<void>.delayed(delay, () async {
      if (_manualDisconnect) return;
      await connect(
        _host!,
        _privateKey!,
        passphrase: _passphrase,
        onUnknownHostKey: _onUnknownHostKey,
        onHostKeyChanged: _onHostKeyChanged,
        attempt: nextAttempt,
      );
    });
  }

  Future<void> _handleClosed(TunnelSession session) async {
    if (_manualDisconnect || _session != session) return;
    _session = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    await session.close();
    if (state.phase == ConnectionPhase.ready ||
        state.phase == ConnectionPhase.reconnecting) {
      _scheduleRetry();
    }
  }

  /// Waits for [work] at most [connectTimeout]. A session that arrives after
  /// the deadline is closed, so a hung attempt cannot leak a tunnel.
  Future<T> _withDeadline<T>(Future<T> work) {
    return work.timeout(
      connectTimeout,
      onTimeout: () {
        unawaited(
          work.then((value) async {
            if (value is TunnelSession) await value.close();
          }, onError: (_) {}),
        );
        throw ServerUnreachable(AppL10n.t.connectionTimedOut);
      },
    );
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(keepAliveInterval, (_) => _keepAliveOnce());
  }

  /// One heartbeat. Skipped while the previous one is still in flight, and a
  /// heartbeat that outlives [keepAliveTimeout] counts as a dead link.
  Future<void> _keepAliveOnce() async {
    final session = _session;
    if (session == null || _keepAliveBusy) return;
    _keepAliveBusy = true;
    try {
      await session.keepAlive().timeout(keepAliveTimeout);
    } catch (_) {
      _handleClosed(session);
    } finally {
      _keepAliveBusy = false;
    }
  }

  Future<void> _closeSession() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    final session = _session;
    _session = null;
    await session?.close();
  }

  void _set(ConnectionPhase phase) {
    state = ConnectionSnapshot(phase: phase);
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    await _closeSession();
    state = const ConnectionSnapshot(phase: ConnectionPhase.idle);
  }
}
