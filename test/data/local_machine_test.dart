import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/data/host_store.dart';
import 'package:tinydesk/data/local_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensure adds the built-in local host once (idempotent)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesHostStore();
    final machine = const LocalMachine();

    await machine.ensure(store);
    var hosts = await store.load();
    expect(hosts, hasLength(1));
    final builtIn = hosts.single;
    expect(builtIn.id, LocalMachine.localHostId);
    expect(builtIn.type, 'local');
    expect(builtIn.host, '127.0.0.1');
    expect(builtIn.autoStartServer, isTrue);
    expect(builtIn.privateKeyRef, isNull);

    // Second run: no duplicate, user rename preserved.
    final renamed = builtIn.copyWith(name: '我的电脑');
    await store.save([renamed]);
    await machine.ensure(store);
    hosts = await store.load();
    expect(hosts, hasLength(1));
    expect(hosts.single.name, '我的电脑');
  });

  test('ensure picks a free localPort over existing hosts', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesHostStore();

    final ssh = Host(
      id: 'ssh-1',
      name: '远程',
      host: 'example.com',
      port: 22,
      username: 'u',
      remotePort: 49374,
      localPort: 49375,
      autoStartServer: true,
    );
    await store.save([ssh]);

    await const LocalMachine().ensure(store);
    final hosts = await store.load();
    expect(hosts, hasLength(2));
    final local = hosts.firstWhere((h) => h.id == LocalMachine.localHostId);
    expect(local.localPort, 49376);
  });

  test('ensure coexists with a local host created by a previous version',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesHostStore();

    final legacy = Host(
      id: '508b60cf-old-uuid',
      name: '本地',
      type: 'local',
      host: '127.0.0.1',
      port: 22,
      username: 'someone',
      remotePort: 49374,
      localPort: 49377,
      autoStartServer: true,
    );
    await store.save([legacy]);

    await const LocalMachine().ensure(store);
    final hosts = await store.load();
    // Both survive; the legacy one is a user record, the built-in one is new.
    expect(hosts, hasLength(2));
    expect(hosts.where((h) => h.isLocal), hasLength(2));
    // The list UI puts anything non-built-in aside, so no conflict in practice,
    // but ensure() itself must not delete user records it did not create.
  });
}
