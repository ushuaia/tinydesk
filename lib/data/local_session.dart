import 'dart:async';

import '../core/app_language.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';

import 'host.dart';
import 'local_directory.dart';
import 'remote_file.dart';
import 'shell_session.dart';
import '../opencode/opencode_client.dart';
import '../opencode/opencode_errors.dart';
import '../ssh/tunnel_session.dart';
/// A [TunnelSession] backed by local file IO and the locally running
/// opencode binary — no SSH involved.
///
/// To keep the per-host cookie isolation intact the workspace always talks to
/// `127.0.0.1:<host.localPort>`, exactly like an SSH host. [LocalSession] binds
/// a tiny loopback forwarder on that port and relays every connection to the
/// real opencode HTTP service port discovered on this machine.
class LocalSession implements TunnelSession {
  LocalSession._(this._host);

  final Host _host;
  final OpencodeClient _opencode = OpencodeClient();
  ServerSocket? _forward;
  final Completer<void> _closed = Completer<void>();

  /// Detects the real opencode service port on this machine, starts the
  /// service when missing, and binds the loopback forwarder on
  /// [Host.localPort].
  static Future<LocalSession> open(Host host) async {
    final session = LocalSession._(host);
    try {
      final servicePort = await session._ensureService();
      await session._startForward(servicePort);
      return session;
    } catch (error) {
      await session.close();
      rethrow;
    }
  }

  Future<int> _ensureService() async {
    // The opencode service is briefly unavailable while it auto-updates or
    // when a TUI restarts it (SIGTERM old server, start the new one): probes
    // then answer 500 for a few seconds. Retry around that window instead of
    // failing the whole connect.
    // A freshly upgraded opencode can take tens of seconds to come up the
    // first time (migration, plugin init). Probe for ~20s instead of giving
    // up after a couple of seconds; ask the daemon to start only early on.
    for (var attempt = 0; attempt < 10; attempt++) {
      var port = await _detectServerPort();
      if (port != null) return port;
      if (_host.autoStartServer && attempt < 3) {
        // A startService() hiccup (odd CLI output, slow daemon) must not
        // abort the loop: the next probe decides whether it actually came up.
        try {
          await startService();
        } catch (error) {
          debugPrint('startService failed: $error');
        }
        port = await _detectServerPort();
        if (port != null) return port;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw ServerUnreachable(AppL10n.t.localServiceUnreachable);
  }

  /// Resolves the opencode binary on this machine. Uses the user's login
  /// shell (which applies the real PATH from .zshrc/.bashrc) plus an
  /// absolute-path candidate list, because `Process.run` inside a sandboxed
  /// app does not inherit the user's shell PATH.
  Future<String?> _findBinary() async {
    final home = Platform.environment['HOME'] ?? '';
    // 1. Ask the login shell — most reliable when PATH is customised.
    for (final shell in const ['/bin/zsh', '/bin/bash']) {
      if (!File(shell).existsSync()) continue;
      try {
        final result = await Process.run(shell, ['-lc', 'command -v opencode'])
            .timeout(const Duration(seconds: 15));
        if (result.exitCode == 0) {
          final out = result.stdout.toString().trim();
          if (out.isNotEmpty) return out.split('\n').last.trim();
        }
      } catch (_) {}
    }
    // 2. Fall back to absolute-path candidates.
    final candidates = [
      'opencode',
      '$home/.opencode/bin/opencode',
      '$home/.local/bin/opencode',
      '$home/.npm-global/bin/opencode',
      '$home/.bun/bin/opencode',
      '/opt/homebrew/bin/opencode',
      '/usr/local/bin/opencode',
    ];
    for (final candidate in candidates) {
      try {
        final result = await Process.run(
          '/bin/sh',
          ['-c', 'command -v "$candidate" 2>/dev/null'],
        );
        if (result.exitCode == 0) {
          final out = result.stdout.toString().trim();
          if (out.isNotEmpty) {
            return out.split('\n').last.trim();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Probes the well-known opencode ports on the loopback. `localPort` is
  /// skipped: that port belongs to this session's own forwarder.
  Future<int?> _detectServerPort() async {
    for (final port in const [49374, 4096, 3000, 8080, 19001]) {
      if (port == _host.localPort) continue;
      if (await _portAlive(port)) return port;
    }
    return null;
  }

  Future<bool> _portAlive(int port) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/api/info'),
      );
      final response = await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      return response.statusCode == 200 || response.statusCode == 401;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _startForward(int servicePort) async {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      _host.localPort,
    );
    server.listen(
      (client) {
        Socket.connect(InternetAddress.loopbackIPv4, servicePort).then((remote) {
          // Bidirectional relay with explicit teardown on either side
          // resetting or finishing. Stream.pipe alone leaves the peer open
          // and raises uncaught SocketExceptions when the server closes an
          // idle keep-alive connection.
          var closed = false;
          void closeBoth() {
            if (closed) return;
            closed = true;
            try {
              client.destroy();
            } catch (_) {}
            try {
              remote.destroy();
            } catch (_) {}
          }

          // Socket errors also surface asynchronously on `done`; capture
          // them so a peer reset never becomes an unhandled exception.
          unawaited(client.done.catchError((_) {}));
          unawaited(remote.done.catchError((_) {}));

          // Proper TCP relay: half-close the write side instead of tearing
          // the whole socket down, otherwise an HTTP client that finishes
          // its request (FIN) loses the response and the WebView reports a
          // reset connection.
          client.listen(
            (data) {
              try {
                remote.add(data);
              } catch (_) {
                closeBoth();
              }
            },
            onError: (_) => closeBoth(),
            onDone: () {
              // Request finished; keep reading the response.
              unawaited(remote.close().catchError((_) {}));
            },
            cancelOnError: true,
          );
          remote.listen(
            (data) {
              try {
                client.add(data);
              } catch (_) {
                closeBoth();
              }
            },
            onError: (_) => closeBoth(),
            onDone: () {
              unawaited(client.close().catchError((_) {}));
              closeBoth();
            },
            cancelOnError: true,
          );
        }).catchError((_) {
          client.destroy();
        });
      },
      onError: (Object _) {
        if (!_closed.isCompleted) _closed.complete();
      },
      onDone: () {
        if (!_closed.isCompleted) _closed.complete();
      },
      cancelOnError: false,
    );
    _forward = server;
  }

  @override
  Future<ServerStatus> probe(String baseUrl) => _opencode.probe(baseUrl);

  @override
  Future<String> createPairLink(String localBaseUrl) async {
    final pairResult = await _runOpencode(['pair', '--url', localBaseUrl]);
    final url = parsePairUrl(pairResult);
    if (url == null) {
      throw PairingFailed(AppL10n.t.parsePairFailedRaw(pairResult));
    }
    return url;
  }

  @override
  Future<void> startService() async {
    final result = await _runOpencode(['service', 'start']);
    final trimmed = result.trim();
    if (!trimmed.contains('http://') && !trimmed.contains('https://')) {
      throw ServiceStartFailed(AppL10n.t.localServiceStartFailed(trimmed));
    }
  }

  Future<String> _runOpencode(List<String> args) async {
    final binary = await _findBinary();
    if (binary == null) {
      throw OpencodeNotInstalled(AppL10n.t.localOpencodeMissing);
    }
    var result = await Process.run(binary, args)
        .timeout(const Duration(seconds: 30));
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw PairingFailed(err.isEmpty ? AppL10n.t.opencodeCommandFailed : err);
    }
    return result.stdout.toString();
  }

  @override
  Future<List<RemoteFile>> listDirectory(String path) =>
      listLocalDirectory(path);

  @override
  Future<String> readText(String path) => File(path).readAsString();

  @override
  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  @override
  Future<void> writeText(String path, String content) =>
      File(path).writeAsString(content);

  @override
  Future<String> runCommand(String command) async {
    final result = await Process.run('/bin/sh', ['-c', command])
        .timeout(const Duration(seconds: 15));
    if (result.exitCode != 0) {
      throw TunnelCommandException(
        command,
        exitCode: result.exitCode,
        stderr: result.stderr.toString(),
      );
    }
    return result.stdout.toString();
  }

  @override
  Future<void> delete(String path) async {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  @override
  Future<void> createDirectory(String path) async {
    await Directory(path).create(recursive: true);
  }

  @override
  Future<void> downloadFile(String remotePath, File destination) async {
    final parent = destination.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    await File(remotePath).copy(destination.path);
  }

  @override
  Future<DateTime?> statModified(String path) async {
    try {
      final stat = FileStat.statSync(path);
      if (stat.type == FileSystemEntityType.notFound) return null;
      return stat.modified;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> homeDirectory() async {
    return Platform.environment['HOME'] ?? '/';
  }

  @override
  Future<ShellSession> openShell({int width = 80, int height = 24}) async {
    final shellPath = Platform.environment['SHELL'] ?? '/bin/zsh';
    final home = Platform.environment['HOME'];
    final pty = Pty.start(
      shellPath,
      arguments: const ['-l'],
      workingDirectory: home,
      rows: height,
      columns: width,
    );
    return LocalShellSession(pty);
  }

  @override
  Future<void> keepAlive() async {}

  @override
  Future<void> close() async {
    final server = _forward;
    _forward = null;
    await server?.close();
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  Future<void> get closed => _closed.future;
}
