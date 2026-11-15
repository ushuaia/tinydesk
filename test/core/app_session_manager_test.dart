import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/shell_session.dart';
import 'package:tinydesk/core/app_session_manager.dart';
import 'package:tinydesk/core/connection_controller.dart';
import 'package:tinydesk/core/connection_state.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/data/host_repository.dart';
import 'package:tinydesk/data/host_store.dart';
import 'package:tinydesk/data/open_sessions_store.dart';
import 'package:tinydesk/data/private_key_store.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/opencode/opencode_client.dart';
import 'package:tinydesk/ssh/tunnel_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSession implements TunnelSession {
  bool isClosed = false;
  final Completer<void> _closed = Completer<void>();

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<ServerStatus> probe(String baseUrl) async => ServerStatus.online;

  @override
  Future<PairingSession> pairSession(String localBaseUrl) async =>
      PairingSession(
        baseUrl: localBaseUrl,
        cookieName: 'sid',
        cookieValue: 'cookie123',
      );

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
  Future<void> keepAlive() async {}

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

Host _host(String id) => Host(
      id: id,
      name: id,
      host: '10.0.0.2',
      port: 22,
      username: 'me',
      remotePort: 49374,
      localPort: 49375,
      autoStartServer: false,
    );

ConnectionController _controller(List<_FakeSession> sessions) {
  return ConnectionController(
    opener: (host, key, passphrase, onUnknown, onChanged) async {
      final session = _FakeSession();
      sessions.add(session);
      return session;
    },
  );
}

AppSessionManager _manager(List<_FakeSession> sessions) {
  return AppSessionManager(
    connectionFactory: () => _controller(sessions),
    backgroundTasks: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('connect activates host and reaches ready', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');

    expect(manager.activeHost?.id, 'h1');
    expect(manager.isReady, isTrue);
    expect(manager.connection.state.phase, ConnectionPhase.ready);
  });

  test('disconnect closes only the active session', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');
    await manager.disconnect();

    expect(manager.activeHost, isNull);
    expect(manager.sessions, isEmpty);
    expect(manager.connection.state.phase, ConnectionPhase.idle);
    expect(sessions.single.isClosed, isTrue);
  });

  test('opening another host keeps the previous session alive', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');
    await manager.connect(_host('h2'), 'KEY');

    expect(manager.activeHost?.id, 'h2');
    expect(manager.sessions, hasLength(2));
    expect(sessions, hasLength(2));
    // Multi-session: the first host's tunnel and terminal stay alive.
    expect(sessions.first.isClosed, isFalse);
    expect(sessions.last.isClosed, isFalse);

    // Switching back only changes the active session.
    manager.activate('h1');
    expect(manager.activeHost?.id, 'h1');
    expect(sessions.first.isClosed, isFalse);
  });

  test('closeSession tears down only that host', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');
    await manager.connect(_host('h2'), 'KEY');
    await manager.closeSession('h1');

    expect(manager.sessions, hasLength(1));
    expect(manager.activeHost?.id, 'h2');
    expect(sessions.first.isClosed, isTrue);
    expect(sessions.last.isClosed, isFalse);
  });

  test('open sessions persist and restore on next launch', () async {
    final sessions = <_FakeSession>[];
    final repository = HostRepository(SharedPreferencesHostStore());
    final keyStore = PrivateKeyStore();
    await repository.upsert(_host('h1'));
    await repository.upsert(_host('h2'));
    await keyStore.save('h1', 'KEY1', null);
    await keyStore.save('h2', 'KEY2', null);

    final first = _manager(sessions);
    await first.connect(_host('h1'), 'KEY1');
    await first.connect(_host('h2'), 'KEY2');
    first.activate('h1');
    await Future<void>.delayed(Duration.zero);
    // Persist is async; give it a tick.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final stored = await OpenSessionsStore().load();
    expect(stored.hostIds, ['h1', 'h2']);
    expect(stored.activeHostId, 'h1');
    first.dispose();

    final restoredSessions = <_FakeSession>[];
    final second = _manager(restoredSessions);
    addTearDown(second.dispose);
    await second.restore(repository: repository, keyStore: keyStore);

    expect(second.sessions, hasLength(2));
    expect(second.activeHost?.id, 'h1');
  });

  test('each session owns a file browser controller', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');

    final session = manager.activeSession!;
    expect(manager.fileBrowser, same(session.fileBrowser));
    expect(manager.fileBrowserOf('h1'), same(session.fileBrowser));
    expect(manager.fileBrowser!.visible, isFalse);
  });

  test('closing a session drops its file browser', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');
    await manager.closeSession('h1');

    expect(manager.fileBrowser, isNull);
    expect(manager.fileBrowserOf('h1'), isNull);
  });

  test('sessionOf returns a session by host id', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');

    expect(manager.sessionOf('h1'), same(manager.activeSession));
    expect(manager.sessionOf('missing'), isNull);
  });

  test('showing the file browser collapses the terminal window', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');
    final session = manager.activeSession!;
    await session.terminal.show();
    expect(session.terminal.expanded, isTrue);

    manager.showFileBrowser();

    expect(session.terminal.expanded, isFalse);
    expect(session.fileBrowser.expanded, isTrue);
    expect(session.fileBrowser.visible, isTrue);
  });

  test('showing the terminal collapses the file browser', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');
    final session = manager.activeSession!;
    session.fileBrowser.show();

    await manager.showTerminal();

    expect(session.fileBrowser.expanded, isFalse);
    expect(session.fileBrowser.visible, isTrue);
    expect(session.terminal.expanded, isTrue);
  });

  test('handleFileBrowserBack minimizes only an expanded browser', () async {
    final sessions = <_FakeSession>[];
    final manager = _manager(sessions);
    addTearDown(manager.dispose);

    await manager.connect(_host('h1'), 'KEY');
    final session = manager.activeSession!;

    expect(manager.handleFileBrowserBack(), isFalse);

    manager.showFileBrowser();
    expect(session.fileBrowser.expanded, isTrue);

    expect(manager.handleFileBrowserBack(), isTrue);
    expect(session.fileBrowser.expanded, isFalse);
    expect(session.fileBrowser.visible, isTrue);
  });
}
