import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/project_metadata_store.dart';

import '../support/fake_tunnel_session.dart';

class _MemorySession extends FakeTunnelSession {
  final Map<String, String> storage = {};
  final List<String> deletes = [];
  bool failWrites = false;
  Object? readError;

  @override
  Future<String> readText(String path) async {
    if (readError != null) throw readError!;
    final value = storage[path];
    if (value == null) {
      throw SftpStatusError(SftpStatusCode.noSuchFile, 'missing $path');
    }
    return value;
  }

  @override
  Future<void> writeText(String path, String content) async {
    if (failWrites) throw FileSystemException('denied', path);
    storage[path] = content;
  }

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> delete(String path) async {
    deletes.add(path);
    storage.remove(path);
  }
}

Map<String, dynamic> _payload(String value) => {'value': value};

void main() {
  test('scoped metadata lives under users/<name>', () {
    final store = ProjectMetadataStore(
      session: _MemorySession(),
      projectRoot: '/p',
      userScope: 'alice',
    );

    expect(store.pathFor('favorites.json'),
        '/p/.tinydesk/users/alice/favorites.json');
  });

  test('sanitizes unsafe characters in the scope', () {
    final store = ProjectMetadataStore(
      session: _MemorySession(),
      projectRoot: '/p',
      userScope: 'a/b c',
    );

    expect(store.pathFor('favorites.json'),
        '/p/.tinydesk/users/a_b_c/favorites.json');
  });

  test('an empty scope keeps the legacy path', () {
    final store = ProjectMetadataStore(
      session: _MemorySession(),
      projectRoot: '/p',
    );

    expect(store.pathFor('favorites.json'), '/p/.tinydesk/favorites.json');
  });

  test('adopts the shared legacy file once and removes it', () async {
    final session = _MemorySession();
    session.storage['/p/.tinydesk/favorites.json'] =
        jsonEncode(_payload('legacy'));

    final store = ProjectMetadataStore(
      session: session,
      projectRoot: '/p',
      userScope: 'alice',
    );

    final data = await store.readJson('favorites.json');

    expect(data?['value'], 'legacy');
    expect(
      session.storage['/p/.tinydesk/users/alice/favorites.json'],
      isNotNull,
    );
    expect(session.storage.containsKey('/p/.tinydesk/favorites.json'), isFalse);
    expect(session.deletes, contains('/p/.tinydesk/favorites.json'));
  });

  test('keeps the legacy file when the migration write fails', () async {
    final session = _MemorySession()..failWrites = true;
    session.storage['/p/.tinydesk/favorites.json'] =
        jsonEncode(_payload('legacy'));

    final store = ProjectMetadataStore(
      session: session,
      projectRoot: '/p',
      userScope: 'alice',
    );

    final data = await store.readJson('favorites.json');

    expect(data?['value'], 'legacy');
    expect(session.storage.containsKey('/p/.tinydesk/favorites.json'), isTrue);
    expect(session.deletes, isEmpty);
  });

  test('a read error other than a missing file is not treated as empty',
      () async {
    final session = _MemorySession()
      ..storage['/p/.tinydesk/users/alice/favorites.json'] =
          jsonEncode(_payload('alice'))
      ..readError = Exception('connection reset');

    final store = ProjectMetadataStore(
      session: session,
      projectRoot: '/p',
      userScope: 'alice',
    );

    await expectLater(
      () => store.readJson('favorites.json'),
      throwsA(isA<Exception>()),
    );
    expect(session.deletes, isEmpty);
  });

  test('a file that is not a JSON object is an error, not empty', () async {
    final session = _MemorySession()
      ..storage['/p/.tinydesk/favorites.json'] = '[1, 2]';

    final store = ProjectMetadataStore(session: session, projectRoot: '/p');

    await expectLater(
      () => store.readJson('favorites.json'),
      throwsA(isA<FormatException>()),
    );
  });

  test('different users do not see each other data', () async {
    final session = _MemorySession();
    final alice = ProjectMetadataStore(
      session: session,
      projectRoot: '/p',
      userScope: 'alice',
    );
    final bob = ProjectMetadataStore(
      session: session,
      projectRoot: '/p',
      userScope: 'bob',
    );

    await alice.writeJson('favorites.json', _payload('alice'));

    expect((await alice.readJson('favorites.json'))?['value'], 'alice');
    expect(await bob.readJson('favorites.json'), isNull);
  });
}
