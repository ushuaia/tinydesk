import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/session/app_session_manager.dart';
import 'package:tinydesk/data/favorite_store.dart';
import 'package:tinydesk/data/favorite_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

class _MemorySession extends FakeTunnelSession {
  final Map<String, String> storage = {};
  bool failReads = false;

  @override
  Future<String> readText(String path) async {
    if (failReads) throw Exception('connection reset');
    final data = storage[path];
    if (data == null) {
      throw SftpStatusError(SftpStatusCode.noSuchFile, 'missing $path');
    }
    return data;
  }

  @override
  Future<void> writeText(String path, String content) async {
    storage[path] = content;
  }

  @override
  Future<void> createDirectory(String path) async {}
}

FavoriteDocument _doc(String path, {String projectRoot = '/p'}) =>
    FavoriteDocument(
      path: path,
      name: path.split('/').last,
      kind: 'text',
      addedAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      hostId: 'h1',
      projectRoot: projectRoot,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('syncProject merges remote entries into the local list and writes back',
      () async {
    final index = FavoriteIndex();
    await index.add(_doc('/p/local.md'));

    final session = _MemorySession();
    session.storage['/p/.tinydesk/favorites.json'] = jsonEncode({
      'version': 1,
      'favorites': {
        '/p/remote.md': {
          'name': 'remote.md',
          'kind': 'text',
          'addedAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
          'deleted': false,
        },
      },
    });

    final manager = AppSessionManager(backgroundTasks: false);
    addTearDown(manager.dispose);

    await FavoriteSync(manager: manager, index: index).syncProject(
      session: session,
      hostId: 'h1',
      projectRoot: '/p',
    );

    final visible = await index.load();
    expect(
      visible.map((item) => item.path),
      containsAll(['/p/local.md', '/p/remote.md']),
    );
    expect(
      visible.firstWhere((item) => item.path == '/p/remote.md').hostId,
      'h1',
    );

    final pushed = session.storage['/p/.tinydesk/favorites.json']!;
    expect(pushed, contains('/p/local.md'));
    expect(pushed, contains('/p/remote.md'));
  });

  test('deletions travel to the host as tombstones', () async {
    final index = FavoriteIndex();
    await index.add(_doc('/p/old.md'));
    await index.remove(hostId: 'h1', path: '/p/old.md');

    final session = _MemorySession();
    final manager = AppSessionManager(backgroundTasks: false);
    addTearDown(manager.dispose);

    await FavoriteSync(manager: manager, index: index).syncProject(
      session: session,
      hostId: 'h1',
      projectRoot: '/p',
    );

    final pushed = session.storage['/p/.tinydesk/favorites.json']!;
    final decoded = jsonDecode(pushed) as Map<String, dynamic>;
    final entry = (decoded['favorites'] as Map)['/p/old.md'] as Map;
    expect(entry['deleted'], isTrue);
    expect(await index.load(), isEmpty);
  });

  test('an unreadable remote file is neither merged nor overwritten', () async {
    final index = FavoriteIndex();
    await index.add(_doc('/p/local.md'));

    final original = jsonEncode({
      'version': 1,
      'favorites': {
        '/p/remote.md': {
          'name': 'remote.md',
          'kind': 'text',
          'addedAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
          'deleted': false,
        },
      },
    });
    final session = _MemorySession()..failReads = true;
    session.storage['/p/.tinydesk/favorites.json'] = original;

    final manager = AppSessionManager(backgroundTasks: false);
    addTearDown(manager.dispose);

    await FavoriteSync(manager: manager, index: index).syncProject(
      session: session,
      hostId: 'h1',
      projectRoot: '/p',
    );

    expect(session.storage['/p/.tinydesk/favorites.json'], original);
    expect((await index.load()).map((item) => item.path), ['/p/local.md']);
  });

  test('a remote tombstone removes the local favorite', () async {
    final index = FavoriteIndex();
    // Seed an older local entry; `add` stamps "now" and would win instead.
    await index.replaceProject('h1', '/p', [_doc('/p/gone.md')]);

    final session = _MemorySession();
    session.storage['/p/.tinydesk/favorites.json'] = jsonEncode({
      'version': 1,
      'favorites': {
        '/p/gone.md': {
          'name': 'gone.md',
          'kind': 'text',
          'addedAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-02-01T00:00:00.000Z',
          'deleted': true,
        },
      },
    });

    final manager = AppSessionManager(backgroundTasks: false);
    addTearDown(manager.dispose);

    await FavoriteSync(manager: manager, index: index).syncProject(
      session: session,
      hostId: 'h1',
      projectRoot: '/p',
    );

    expect(await index.load(), isEmpty);
  });
}
