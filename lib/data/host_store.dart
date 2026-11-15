import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'host.dart';

abstract class HostStore {
  Future<List<Host>> load();
  Future<void> save(List<Host> hosts);
}

class SharedPreferencesHostStore implements HostStore {
  static const _key = 'hosts.v1';

  @override
  Future<List<Host>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Host.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> save(List<Host> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(hosts.map((h) => h.toJson()).toList()),
    );
  }
}
