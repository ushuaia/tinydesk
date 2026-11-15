import 'dart:io';

import '../core/app_language.dart';

import 'host.dart';
import 'host_store.dart';
import 'port_allocator.dart';

/// The built-in "this machine" host.
///
/// Desktop builds (macOS / Linux / Windows) always have exactly one local
/// host provisioned at startup — no setup needed, tapping it connects
/// through [LocalSession]. Mobile platforms have no local opencode CLI, so
/// `supported` is false and no entry is injected.
class LocalMachine {
  const LocalMachine();

  static const localHostId = 'local-machine';

  static bool get supported =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  /// Guarantees the built-in local host exists, idempotent by stable id.
  /// A previously renamed entry with this id is never overwritten.
  Future<void> ensure(HostStore store) async {
    final hosts = await store.load();
    if (hosts.any((h) => h.id == localHostId)) return;
    final localPort = const PortAllocator().nextAvailable(hosts);
    final host = Host(
      id: localHostId,
      name: AppL10n.t.thisMachine,
      type: 'local',
      host: '127.0.0.1',
      port: 22,
      username: Platform.environment['USER'] ?? 'me',
      remotePort: 49374,
      localPort: localPort,
      autoStartServer: true,
    );
    await store.save([...hosts, host]);
  }
}
