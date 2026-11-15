import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/favorite_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

FavoriteDocument _doc(
  String name, {
  String hostId = 'h1',
  String path = '',
  DateTime? addedAt,
}) {
  return FavoriteDocument(
    path: path.isEmpty ? '/tmp/$name' : path,
    name: name,
    kind: 'text',
    addedAt: addedAt ?? DateTime(2026, 1, 1),
    hostId: hostId,
    projectRoot: '/tmp',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add, load and contains', () async {
    final index = FavoriteIndex();
    expect(await index.load(), isEmpty);

    await index.add(_doc('a.md'));
    await index.add(_doc('b.dart'));

    final items = await index.load();
    expect(items, hasLength(2));
    expect(await index.contains('h1', '/tmp/a.md'), isTrue);
    expect(await index.contains('h1', '/tmp/missing'), isFalse);
  });

  test('adding the same host+path replaces the entry', () async {
    final index = FavoriteIndex();
    await index.add(_doc('a.md', addedAt: DateTime(2026, 1, 1)));
    await index.add(_doc('a.md', addedAt: DateTime(2026, 1, 2)));

    final items = await index.load();
    expect(items, hasLength(1));
    expect(items.single.addedAt, DateTime(2026, 1, 2));
  });

  test('remove, removeForHost and clearAll', () async {
    final index = FavoriteIndex();
    await index.add(_doc('a.md'));
    await index.add(_doc('b.md', hostId: 'h2'));

    await index.remove(hostId: 'h1', path: '/tmp/a.md');
    expect((await index.load()).single.name, 'b.md');

    await index.add(_doc('c.md'));
    await index.removeForHost('h2');
    expect((await index.load()).single.name, 'c.md');

    await index.clearAll();
    expect(await index.load(), isEmpty);
  });
}
