import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/data/shell_session.dart';
import 'package:tinydesk/opencode/opencode_client.dart';
import 'package:tinydesk/ssh/tunnel_session.dart';

/// Minimal [TunnelSession] for widget tests: empty listings, no-op writes.
class FakeTunnelSession implements TunnelSession {
  FakeTunnelSession({this.home = '/home/test', this.files = const []});

  final String home;
  final List<RemoteFile> files;
  final Completer<void> _closed = Completer<void>();

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<ServerStatus> probe(String baseUrl) async => ServerStatus.online;

  @override
  Future<String> createPairLink(String localBaseUrl) async =>
      'http://127.0.0.1:49374/auth/connect/test';

  @override
  Future<void> startService() async {}

  @override
  Future<List<RemoteFile>> listDirectory(String path) async => files;

  @override
  Future<String> readText(String path) async => '';

  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);

  @override
  Future<Uint8List> readHead(String path, int length) async =>
      Uint8List(0);

  @override
  Future<void> writeText(String path, String content) async {}

  @override
  Future<void> delete(String path) async {}

  @override
  Future<String> runCommand(String command) async => '';

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> downloadFile(String remotePath, File destination) async {}

  @override
  Future<DateTime?> statModified(String path) async => null;

  @override
  Future<String> homeDirectory() async => home;

  @override
  Future<ShellSession> openShell({int width = 80, int height = 24}) {
    throw UnimplementedError();
  }

  @override
  Future<void> keepAlive() async {}

  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
  }
}
