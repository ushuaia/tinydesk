import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/favorite_store.dart';

FavoriteDocument _doc(
  String path, {
  DateTime? addedAt,
  DateTime? updatedAt,
  bool deleted = false,
  String? hostId = 'h1',
  String? projectRoot = '/project',
}) {
  return FavoriteDocument(
    path: path,
    name: path.split('/').last,
    kind: 'markdown',
    addedAt: addedAt ?? DateTime.utc(2026, 1, 1),
    updatedAt: updatedAt ?? addedAt ?? DateTime.utc(2026, 1, 1),
    deleted: deleted,
    hostId: hostId,
    projectRoot: projectRoot,
  );
}

void main() {
  group('mergeFavorites', () {
    test('keeps local-only entries', () {
      final merged = mergeFavorites([_doc('/p/a.md')], []);
      expect(merged.map((d) => d.path), ['/p/a.md']);
    });

    test('adds remote-only entries and binds them to the local host', () {
      final merged = mergeFavorites(
        [],
        [_doc('/p/b.md', hostId: null, projectRoot: null)],
        hostId: 'h1',
        projectRoot: '/project',
      );
      expect(merged, hasLength(1));
      expect(merged.single.hostId, 'h1');
      expect(merged.single.projectRoot, '/project');
    });

    test('newer remote wins', () {
      final merged = mergeFavorites(
        [_doc('/p/a.md', updatedAt: DateTime.utc(2026, 1, 1))],
        [_doc('/p/a.md', updatedAt: DateTime.utc(2026, 2, 1))],
        hostId: 'h1',
        projectRoot: '/project',
      );
      expect(merged.single.updatedAt, DateTime.utc(2026, 2, 1));
    });

    test('newer local wins', () {
      final merged = mergeFavorites(
        [_doc('/p/a.md', updatedAt: DateTime.utc(2026, 3, 1))],
        [_doc('/p/a.md', updatedAt: DateTime.utc(2026, 2, 1))],
        hostId: 'h1',
        projectRoot: '/project',
      );
      expect(merged.single.updatedAt, DateTime.utc(2026, 3, 1));
    });

    test('a newer deletion wins over an older favorite', () {
      final merged = mergeFavorites(
        [_doc('/p/a.md', updatedAt: DateTime.utc(2026, 1, 1))],
        [
          _doc(
            '/p/a.md',
            updatedAt: DateTime.utc(2026, 2, 1),
            deleted: true,
          ),
        ],
        hostId: 'h1',
        projectRoot: '/project',
      );
      expect(merged.single.deleted, isTrue);
    });

    test('an older deletion does not resurrect or hide a newer favorite', () {
      final merged = mergeFavorites(
        [_doc('/p/a.md', updatedAt: DateTime.utc(2026, 3, 1))],
        [
          _doc(
            '/p/a.md',
            updatedAt: DateTime.utc(2026, 2, 1),
            deleted: true,
          ),
        ],
        hostId: 'h1',
        projectRoot: '/project',
      );
      expect(merged.single.deleted, isFalse);
    });
  });

  group('remote favorites JSON', () {
    test('round-trips through the project file format', () {
      final docs = [
        _doc('/p/a.md', updatedAt: DateTime.utc(2026, 2, 1)),
        _doc('/p/b.md', deleted: true, updatedAt: DateTime.utc(2026, 3, 1)),
      ];
      final json = serializeRemoteFavorites(docs);
      final parsed = parseRemoteFavorites(
        json,
        hostId: 'h1',
        projectRoot: '/project',
      );

      expect(parsed, hasLength(2));
      expect(parsed.first.path, '/p/a.md');
      expect(parsed.first.hostId, 'h1');
      expect(parsed.last.deleted, isTrue);
    });

    test('ignores malformed payloads', () {
      expect(
        parseRemoteFavorites(null, hostId: 'h1', projectRoot: '/p'),
        isEmpty,
      );
      expect(
        parseRemoteFavorites({'favorites': 'nope'}, hostId: 'h1', projectRoot: '/p'),
        isEmpty,
      );
    });
  });

  test('older local entries without updatedAt fall back to addedAt', () {
    final doc = FavoriteDocument.fromJson({
      'path': '/p/a.md',
      'name': 'a.md',
      'kind': 'markdown',
      'addedAt': '2026-01-01T00:00:00.000Z',
      'hostId': 'h1',
      'projectRoot': '/project',
    });
    expect(doc.updatedAt, doc.addedAt);
    expect(doc.deleted, isFalse);
  });
}
