import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/data/host_repository.dart';
import 'package:tinydesk/data/host_store.dart';
import 'package:tinydesk/data/local_data_cleaner.dart';
import 'package:tinydesk/data/private_key_store.dart';
import 'package:tinydesk/data/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'theme.dark': true,
      'favorites.v1': '[]',
      'reading.progress.h1:/p/a.md': 0.5,
      'reading.state.h1:/p/a.md': '{}',
      'explorer.expanded.v1.h1': '[]',
      'workspace.url.v1.h1': 'http://127.0.0.1:1/',
      'open.sessions.v1': '{"ids":["h1"],"active":"h1"}',
    });
  });

  test('clears hosts, keys and per-host state but keeps settings', () async {
    final repository = HostRepository(SharedPreferencesHostStore());
    await repository.upsert(_host('h1'));
    final secret = _FakeSecretStore();
    final keyStore = PrivateKeyStore(secret);
    await keyStore.save('h1', 'KEY', 'pass');

    await LocalDataCleaner(
      repository: repository,
      keyStore: keyStore,
    ).clear();

    expect(await repository.all(), isEmpty);
    expect(secret.values, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('theme.dark'), isTrue);
    expect(prefs.getDouble('reading.progress.h1:/p/a.md'), isNull);
    expect(prefs.getString('reading.state.h1:/p/a.md'), isNull);
    expect(prefs.getString('explorer.expanded.v1.h1'), isNull);
    expect(prefs.getString('workspace.url.v1.h1'), isNull);
    expect(prefs.getString('favorites.v1'), isNull);
    expect(prefs.getString('open.sessions.v1'), isNull);
  });
}
