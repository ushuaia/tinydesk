import 'package:shared_preferences/shared_preferences.dart';

import '../session/app_session_manager.dart';
import 'favorite_store.dart';
import 'host_repository.dart';
import '../platform/web_data.dart';
import 'open_sessions_store.dart';
import 'private_key_store.dart';

/// Removes every piece of local state tied to hosts, keys and browsing.
///
/// Device preferences (theme, font scale, keep-alive) are deliberately kept.
class LocalDataCleaner {
  const LocalDataCleaner({
    required this.repository,
    required this.keyStore,
    this.manager,
  });

  final HostRepository repository;
  final PrivateKeyStore keyStore;
  final AppSessionManager? manager;

  /// Keys that only make sense for a host that is about to disappear.
  static const _statePrefixes = [
    'reading.',
    'explorer.',
    'workspace.',
  ];

  Future<void> clear() async {
    final hosts = await repository.all();

    final manager = this.manager;
    if (manager != null) {
      for (final host in hosts) {
        if (manager.hasSession(host.id)) {
          await manager.closeSession(host.id);
        }
      }
    }

    for (final host in hosts) {
      await keyStore.delete(host.id);
    }
    await repository.clear();

    await OpenSessionsStore().clear();
    await FavoriteIndex().clearAll();
    // The embedded WebViews keep opencode session cookies; clearing local
    // data must not leave a logged-in web session behind.
    await const WebData().clearCookies();

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (_statePrefixes.any(key.startsWith)) {
        await prefs.remove(key);
      }
    }
  }
}
