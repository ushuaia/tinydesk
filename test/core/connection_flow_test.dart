import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/shell_session.dart';
import 'package:tinydesk/core/connection_controller.dart';
import 'package:tinydesk/core/connection_state.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/opencode/opencode_client.dart';
import 'package:tinydesk/ssh/tunnel_session.dart';

class FakeSession implements TunnelSession {
  FakeSession({this.online = true});

  final bool online;
  int probes = 0;
  bool isClosed = false;
  int keepAlives = 0;
  final Completer<void> _closed = Completer<void>();

  void simulateDrop() {
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<ServerStatus> probe(String baseUrl) async {
    probes++;
    return online ? ServerStatus.online : ServerStatus.offline;
  }

  @override
  Future<String> createPairLink(String localBaseUrl) async =>
      'http://127.0.0.1:49374/auth/connect/test';

  @override
  Future<void> startService() async {}

  @override
  Future<List<RemoteFile>> listDirectory(String path) async => [];

  @override
  Future<String> readText(String path) async => '';

  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);

  @override
  @override
  Future<String> runCommand(String command) async => '';

  @override
  Future<void> delete(String path) async {}

  @override
  Future<void> writeText(String path, String content) async {}

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> downloadFile(String remotePath, File destination) async {}

  @override
  Future<DateTime?> statModified(String path) async => null;

  @override
  Future<String> homeDirectory() async => '/home/test';

  @override
  Future<ShellSession> openShell({int width = 80, int height = 24}) {
    throw UnimplementedError();
  }

  @override
  Future<void> keepAlive() async {
    keepAlives++;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

Host buildHost({bool autoStart = false}) => Host(
      id: 'h1',
      name: 'dev',
      host: '10.0.0.2',
      port: 22,
      username: 'me',
      remotePort: 49374,
      localPort: 49375,
      autoStartServer: autoStart,
    );

void main() {
  test('connect walks phases and lands on ready', () async {
    final session = FakeSession();
    final controller = ConnectionController(
      opener: (host, key, passphrase, onUnknown, onChanged) async => session,
    );

    final phases = <ConnectionPhase>[];
    controller.addListener(() => phases.add(controller.state.phase));

    await controller.connect(buildHost(), 'KEY');

    expect(phases, [
      ConnectionPhase.sshConnecting,
      ConnectionPhase.tunneling,
      ConnectionPhase.probing,
      ConnectionPhase.pairing,
      ConnectionPhase.ready,
    ]);
    // The snapshot carries the one-time pairing link; the login itself
    // happens in the WebView and the cookie is attached afterwards.
    expect(
      controller.state.pairUrl,
      'http://127.0.0.1:49374/auth/connect/test',
    );
    expect(controller.state.cookieName, isNull);
    expect(controller.state.cookieValue, isNull);
  });

  test('offline without auto-start fails with readable message', () async {
    final session = FakeSession(online: false);
    final controller = ConnectionController(
      opener: (host, key, passphrase, onUnknown, onChanged) async => session,
    );

    await controller.connect(buildHost(), 'KEY');

    expect(controller.state.phase, ConnectionPhase.failed);
    expect(controller.state.message, contains('not responding'));
  });

  test('offline with auto-start retries probe once', () async {
    final session = FakeSession(online: false);
    final controller = ConnectionController(
      opener: (host, key, passphrase, onUnknown, onChanged) async => session,
    );

    await controller.connect(buildHost(autoStart: true), 'KEY');

    expect(session.probes, 2);
    expect(controller.state.phase, ConnectionPhase.failed);
  });

  test('disconnect closes session and returns to idle', () async {
    final session = FakeSession();
    final controller = ConnectionController(
      opener: (host, key, passphrase, onUnknown, onChanged) async => session,
    );

    await controller.connect(buildHost(), 'KEY');
    await controller.disconnect();

    expect(session.isClosed, isTrue);
    expect(controller.state.phase, ConnectionPhase.idle);
  });

  test('connect closes the previous session before reconnecting', () async {
    final first = FakeSession();
    final second = FakeSession();
    var opens = 0;
    final controller = ConnectionController(
      opener: (host, key, passphrase, onUnknown, onChanged) async {
        opens++;
        return opens == 1 ? first : second;
      },
    );

    await controller.connect(buildHost(), 'KEY');
    await controller.connect(buildHost(), 'KEY');

    expect(first.isClosed, isTrue);
    expect(controller.state.phase, ConnectionPhase.ready);
    await controller.disconnect();
  });

  test('session drop triggers reconnect with backoff', () async {
    final first = FakeSession();
    final second = FakeSession();
    var opens = 0;
    final controller = ConnectionController(
      opener: (host, key, passphrase, onUnknown, onChanged) async {
        opens++;
        return opens == 1 ? first : second;
      },
    );

    await controller.connect(buildHost(), 'KEY');
    expect(controller.state.phase, ConnectionPhase.ready);

    first.simulateDrop();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.phase, ConnectionPhase.reconnecting);

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(opens, 2);
    expect(controller.state.phase, ConnectionPhase.ready);

    await controller.disconnect();
  });
}
