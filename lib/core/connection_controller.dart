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
  ConnectionController({TunnelOpener? opener})
      : _opener = opener ?? openSshTunnel,
        super(const ConnectionSnapshot(phase: ConnectionPhase.idle));

  ConnectionController.fake()
      : _opener = openSshTunnel,
        super(const ConnectionSnapshot(phase: ConnectionPhase.idle));

  static const _maxRetries = 3;

  final TunnelOpener _opener;
  final Backoff _backoff = Backoff();

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

      final TunnelSession session = host.isLocal
          ? await LocalSession.open(host)
          : await _opener(
              host,
              privateKey,
              passphrase,
              onUnknownHostKey ?? (_) async => true,
              onHostKeyChanged ?? (_, _) async => false,
            );
      _session = session;
      unawaited(session.closed.then((_) => _handleClosed(session)));

      _set(ConnectionPhase.tunneling);
      _set(ConnectionPhase.probing);

      final baseUrl = 'http://127.0.0.1:${host.localPort}';
      var status = await session.probe(baseUrl);

      if (status == ServerStatus.offline && host.autoStartServer) {
        _set(ConnectionPhase.startingServer);
        await session.startService();
        status = await session.probe(baseUrl);
      }

      if (status == ServerStatus.offline) {
        throw ServerUnreachable(AppL10n.t.remoteOpencodeUnreachable);
      }

      _set(ConnectionPhase.pairing);
      final pairing = await session.pairSession(baseUrl);
      state = state.copyWith(
        phase: ConnectionPhase.ready,
        pairUrl: pairing.baseUrl,
        cookieName: pairing.cookieName,
        cookieValue: pairing.cookieValue,
      );
      _startKeepAlive();
    } on SshError catch (error) {
      _fail(error.userMessage);
    } on OpencodeError catch (error) {
      _fail(error.userMessage);
    } catch (error) {
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

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final session = _session;
      if (session == null) return;
      try {
        await session.keepAlive();
      } catch (_) {
        _handleClosed(session);
      }
    });
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
