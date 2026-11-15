import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The set of hosts whose sessions were open when the app last exited.
class OpenSessionsSnapshot {
  const OpenSessionsSnapshot({
    this.hostIds = const [],
    this.activeHostId,
  });

  final List<String> hostIds;
  final String? activeHostId;

  bool get isEmpty => hostIds.isEmpty;
}

/// Persists the open session set so a restart can restore the same hosts.
class OpenSessionsStore {
  static const _key = 'open.sessions.v1';

  Future<OpenSessionsSnapshot> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const OpenSessionsSnapshot();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final ids = (json['ids'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList();
      return OpenSessionsSnapshot(
        hostIds: ids,
        activeHostId: json['active'] as String?,
      );
    } catch (_) {
      return const OpenSessionsSnapshot();
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  Future<void> save(OpenSessionsSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'ids': snapshot.hostIds,
          'active': snapshot.activeHostId,
        }),
      );
    } catch (_) {}
  }
}
