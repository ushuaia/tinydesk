import 'host.dart';
import 'host_store.dart';

class HostRepository {
  HostRepository(this._store);

  final HostStore _store;

  Future<List<Host>> all() => _store.load();

  Future<void> upsert(Host host) async {
    final hosts = await _store.load();
    final index = hosts.indexWhere((h) => h.id == host.id);
    if (index == -1) {
      hosts.add(host);
    } else {
      hosts[index] = host;
    }
    await _store.save(hosts);
  }

  /// Removes every stored host (used by "clear data").
  Future<void> clear() async {
    await _store.save(const []);
  }

  Future<void> delete(String id) async {
    final hosts = await _store.load();
    hosts.removeWhere((h) => h.id == id);
    await _store.save(hosts);
  }
}
