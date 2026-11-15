import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/shell_session.dart';
import 'package:tinydesk/data/reading_progress_store.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/opencode/opencode_client.dart';
import 'package:tinydesk/ssh/tunnel_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySession implements TunnelSession {
  final Map<String, String> files = {};
  final Set<String> directories = {};

  @override
  Future<String> readText(String path) async {
    final content = files[path];
    if (content == null) {
      throw SftpStatusError(2, 'No such file');
    }
    return content;
  }

  @override
  @override
  Future<String> runCommand(String command) async => '';

  @override
  Future<void> delete(String path) async {}

  @override
  Future<void> writeText(String path, String content) async {
    files[path] = content;
  }

  @override
  Future<void> createDirectory(String path) async {
    directories.add(path);
  }

  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);

  @override
  Future<void> downloadFile(String remotePath, File destination) async {}

  @override
  Future<DateTime?> statModified(String path) async => null;

  @override
  Future<String> homeDirectory() async => '/home/test';

  @override
  Future<ServerStatus> probe(String baseUrl) async => ServerStatus.online;

  @override
  Future<PairingSession> pairSession(String localBaseUrl) async =>
      throw UnimplementedError();

  @override
  Future<void> startService() async {}

  @override
  Future<List<RemoteFile>> listDirectory(String path) async => [];

  @override
  Future<ShellSession> openShell({int width = 80, int height = 24}) async =>
      throw UnimplementedError();

  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<void> keepAlive() async {}

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemorySession session;
  late ReadingProgressStore store;
  const hostId = 'h1';
  const path = '/project/docs/foo.md';
  const remotePath = '/project/.tinydesk/reading_progress.json';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = _MemorySession();
    store = ReadingProgressStore(
      session: session,
      projectRoot: '/project',
    );
  });

  test('saveState writes local and remote payloads', () async {
    await store.saveState(
      hostId,
      path,
      state: const {'kind': 'pixels', 'scrollY': 1200.5},
      fontScale: 1.2,
      syncRemote: true,
    );

    final local = await store.loadState(hostId, path);
    expect(local, isNotNull);
    expect(local!.state['scrollY'], 1200.5);
    expect(local.fontScale, 1.2);
    expect(local.state['updatedAt'], isA<String>());

    final remoteRaw = session.files[remotePath];
    expect(remoteRaw, isNotNull);
    final remote = jsonDecode(remoteRaw!) as Map<String, dynamic>;
    final files = remote['files'] as Map<String, dynamic>;
    final entry = files[path] as Map<String, dynamic>;
    expect(entry['kind'], 'pixels');
    expect(entry['scrollY'], 1200.5);
    expect(entry['fontScale'], 1.2);
    expect(entry['updatedAt'], isA<String>());
    expect(session.directories, contains('/project/.tinydesk'));
  });

  test('loadBestState uses remote when local is missing', () async {
    session.files[remotePath] = jsonEncode({
      'version': 1,
      'files': {
        path: {
          'kind': 'anchor',
          'blockIndex': 4,
          'offset': 12,
          'scrollY': 800,
          'fontScale': 1.0,
          'updatedAt': '2026-11-05T20:00:00Z',
        },
      },
    });

    final result = await store.loadBestState(hostId, path);
    expect(result, isNotNull);
    expect(result!.state['blockIndex'], 4);
    expect(result.state['scrollY'], 800);
  });

  test('loadBestState prefers newer remote over local', () async {
    await store.saveState(
      hostId,
      path,
      state: const {'kind': 'pixels', 'scrollY': 100},
      fontScale: 1.0,
    );
    session.files[remotePath] = jsonEncode({
      'version': 1,
      'files': {
        path: {
          'kind': 'pixels',
          'scrollY': 200,
          'fontScale': 1.0,
          'updatedAt': '2999-01-01T00:00:00Z',
        },
      },
    });

    final result = await store.loadBestState(hostId, path);
    expect(result!.state['scrollY'], 200);
  });

  test('loadBestState keeps newer local over remote', () async {
    await store.saveState(
      hostId,
      path,
      state: const {'kind': 'pixels', 'scrollY': 300},
      fontScale: 1.0,
    );
    session.files[remotePath] = jsonEncode({
      'version': 1,
      'files': {
        path: {
          'kind': 'pixels',
          'scrollY': 100,
          'fontScale': 1.0,
          'updatedAt': '2000-01-01T00:00:00Z',
        },
      },
    });

    final result = await store.loadBestState(hostId, path);
    expect(result!.state['scrollY'], 300);
  });
}
