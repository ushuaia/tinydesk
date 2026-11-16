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
import 'package:tinydesk/ssh/ssh_connector.dart';
import 'package:tinydesk/ssh/tunnel_session.dart';

class FakeSession implements TunnelSession {
  final Completer<void> _closed = Completer<void>();

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> keepAlive() async {}

  @override
  Future<ServerStatus> probe(String baseUrl) async => ServerStatus.online;

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
  Future<void> close() async {}
}

Host buildHost() => const Host(
      id: 'h1',
      name: 'dev',
      host: '10.0.0.2',
      port: 22,
      username: 'me',
      remotePort: 49374,
      localPort: 49375,
      autoStartServer: false,
    );

void main() {
  test('default unknown host key handler trusts first connection', () async {
    UnknownHostKeyHandler? captured;
    final controller = ConnectionController(
      opener: (host, key, passphrase, onUnknown, onChanged) async {
        captured = onUnknown;
        return FakeSession();
      },
    );

    await controller.connect(buildHost(), 'KEY');

    expect(captured, isNotNull);
    expect(await captured!('SHA256:abc'), isTrue);
    expect(controller.state.phase, ConnectionPhase.ready);
  });
}
