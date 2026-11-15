import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/data/host_repository.dart';
import 'package:tinydesk/data/host_store.dart';

class InMemoryHostStore implements HostStore {
  List<Host> data = [];
  @override
  Future<List<Host>> load() async => List.of(data);
  @override
  Future<void> save(List<Host> hosts) async => data = List.of(hosts);
}

void main() {
  late HostRepository repo;

  setUp(() {
    repo = HostRepository(InMemoryHostStore());
  });

  test('upsert adds and updates host', () async {
    final host = Host(
      id: 'h1',
      name: 'dev',
      host: '10.0.0.2',
      port: 22,
      username: 'me',
      remotePort: 49374,
      localPort: 49375,
      autoStartServer: false,
    );
    await repo.upsert(host);
    expect((await repo.all()).single.name, 'dev');

    await repo.upsert(host.copyWith(name: 'dev2'));
    expect((await repo.all()).single.name, 'dev2');
  });

  test('delete removes host', () async {
    const host = Host(
      id: 'h1',
      name: 'dev',
      host: '10.0.0.2',
      port: 22,
      username: 'me',
      remotePort: 49374,
      localPort: 49375,
      autoStartServer: false,
    );
    await repo.upsert(host);
    await repo.delete('h1');
    expect(await repo.all(), isEmpty);
  });

  test('json roundtrip keeps all fields', () {
    final host = Host(
      id: 'h1',
      name: 'dev',
      host: '10.0.0.2',
      port: 2222,
      username: 'me',
      privateKeyRef: 'host.h1.privateKey',
      hasPassphrase: true,
      remotePort: 49374,
      localPort: 49375,
      autoStartServer: true,
      knownHostFingerprint: 'SHA256:abc',
      lastConnectedAt: DateTime.parse('2026-11-01T10:00:00Z'),
    );
    expect(Host.fromJson(host.toJson()).toJson(), host.toJson());
  });
}
