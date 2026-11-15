import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/sandbox_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('applyPayload imports only flutter.* keys with proper types', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final count =
        SandboxMigration.applyPayload(prefs, <String, dynamic>{
      'flutter.hosts.v1': '{"hosts":"[]"}',
      'flutter.host.h1.privateKey': '---key---',
      'flutter.last.connected.host': '1.2.3.4',
      'flutter.reading.state.a': '{"kind":"native","scrollY":10}',
      'app.other': 'ignored',
      'flutter.int': 5,
      'flutter.bool': true,
      'flutter.list': ['a', 'b'],
    });

    expect(count, 7);
    expect(prefs.getString('flutter.hosts.v1'), '{"hosts":"[]"}');
    expect(prefs.getString('flutter.host.h1.privateKey'), '---key---');
    expect(prefs.getString('flutter.last.connected.host'), '1.2.3.4');
    expect(prefs.getInt('flutter.int'), 5);
    expect(prefs.getBool('flutter.bool'), true);
    expect(prefs.getStringList('flutter.list'), ['a', 'b']);
    expect(prefs.containsKey('app.other'), isFalse);
  });

  test('marker short-circuits repeat migration', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool(SandboxMigration.markerKey, true);

    final migration = SandboxMigration();
    await migration.apply(prefs);
    // No data written because the marker was already present.
    expect(prefs.getString('flutter.hosts.v1'), isNull);
  });

  test('existing live hosts skip migration and set marker', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('flutter.hosts.v1', '[{"id":"h"}]');

    final migration = SandboxMigration();
    await migration.apply(prefs);
    expect(prefs.getBool(SandboxMigration.markerKey), isTrue);
    expect(prefs.getString('flutter.hosts.v1'), '[{"id":"h"}]');
  });
}
