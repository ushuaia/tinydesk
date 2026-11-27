import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/private_key_store.dart';
import 'package:tinydesk/data/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecretStore implements SecretStore {
  final Map<String, String> values = {};
  int reads = 0;

  @override
  Future<String?> read(String key) async {
    reads++;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and reads private key from secure storage', () async {
    final secret = _FakeSecretStore();
    final store = PrivateKeyStore(secret);

    await store.save('h1', 'PRIVATE KEY', 'pass');

    final result = await store.read('h1');
    expect(result?.$1, 'PRIVATE KEY');
    expect(result?.$2, 'pass');
    expect(secret.values['v2.host.h1.privateKey'], 'PRIVATE KEY');
    expect(secret.values['v2.host.h1.passphrase'], 'pass');
  });

  test('does not write key material to SharedPreferences', () async {
    final secret = _FakeSecretStore();
    final store = PrivateKeyStore(secret);

    await store.save('h1', 'PRIVATE KEY', 'pass');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('host.h1.privateKey'), isNull);
    expect(prefs.getString('host.h1.passphrase'), isNull);
  });

  test('migrates legacy SharedPreferences entries once', () async {
    SharedPreferences.setMockInitialValues({
      'host.h1.privateKey': 'OLD KEY',
      'host.h1.passphrase': 'old pass',
      'unrelated.key': 'keep',
    });
    final secret = _FakeSecretStore();
    final store = PrivateKeyStore(secret);

    final result = await store.read('h1');

    expect(result?.$1, 'OLD KEY');
    expect(result?.$2, 'old pass');
    expect(secret.values['v2.host.h1.privateKey'], 'OLD KEY');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('host.h1.privateKey'), isNull);
    expect(prefs.getString('host.h1.passphrase'), isNull);
    expect(prefs.getString('unrelated.key'), 'keep');
  });

  test('deletes key material', () async {
    final secret = _FakeSecretStore();
    final store = PrivateKeyStore(secret);
    await store.save('h1', 'PRIVATE KEY', 'pass');

    await store.delete('h1');

    expect(await store.read('h1'), isNull);
    expect(secret.values, isEmpty);
  });

  test('saving without a passphrase clears the old one', () async {
    final secret = _FakeSecretStore();
    final store = PrivateKeyStore(secret);
    await store.save('h1', 'KEY', 'pass');

    await store.save('h1', 'KEY', null);

    expect(secret.values['v2.host.h1.passphrase'], isNull);
    expect((await store.read('h1'))?.$2, isNull);
  });

  test('repeat reads hit the secure store once', () async {
    final secret = _FakeSecretStore()
      ..values['v2.host.h1.privateKey'] = 'KEY'
      ..values['v2.host.h1.passphrase'] = 'pass';
    final store = PrivateKeyStore(secret);
    secret.reads = 0;

    await store.read('h1');
    await store.read('h1');
    await store.read('h1');

    expect(secret.reads, 2); // key + passphrase, once
  });

  test('a host without a passphrase only reads the key', () async {
    final secret = _FakeSecretStore()..values['v2.host.h1.privateKey'] = 'KEY';
    final store = PrivateKeyStore(secret);
    secret.reads = 0;

    final result = await store.read('h1', hasPassphrase: false);

    expect(result?.$1, 'KEY');
    expect(secret.reads, 1);
  });

  test('saving refreshes the cached value', () async {
    final secret = _FakeSecretStore();
    final store = PrivateKeyStore(secret);
    await store.save('h1', 'OLD', 'pass');
    await store.read('h1');

    await store.save('h1', 'NEW', null);

    final result = await store.read('h1');
    expect(result?.$1, 'NEW');
    expect(result?.$2, isNull);
  });

  test('a legacy item is copied under the current signature once', () async {
    final secret = _FakeSecretStore()..values['host.h1.privateKey'] = 'KEY';
    final store = PrivateKeyStore(secret);

    await store.read('h1');
    expect(secret.values['v2.host.h1.privateKey'], 'KEY');

    // A fresh instance (empty cache) reads only the v2 item.
    final next = PrivateKeyStore(secret);
    secret.reads = 0;
    final result = await next.read('h1', hasPassphrase: false);

    expect(result?.$1, 'KEY');
    expect(secret.reads, 1);
  });
}
