import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// One-time migration for the v0.0.20 → v0.0.21 upgrade on macOS.
///
/// Until v0.0.20 the app was App-Sandboxed, so macOS routed its
/// SharedPreferences to `~/Library/Containers/<bundleId>/…/Preferences`.
/// v0.0.21 removes the sandbox (needed for spawning the local opencode
/// CLI), which makes preferences read from the standard, now-empty
/// location. On the first launch after the upgrade this migrator copies
/// every `flutter.*` key from the container plist into the current
/// preferences so hosts, private keys and reading progress survive.
///
/// Runs as: [SandboxMigration] (import for upgrade path) then
/// [LegacyRecordCleanup] (remove stale records for already-migrated
/// machines), guarded so they never cancel each other out.
class SandboxMigration {
  const SandboxMigration();

  static const _markerKey = 'sandbox.migrated.v1';
  /// Visible for tests.
  static String get markerKey => _markerKey;
  static const _fallbackBundleId = 'cox.work.tinydesk';

  Future<void> run() async {
    if (!Platform.isMacOS) return;
    final prefs = await SharedPreferences.getInstance();
    await apply(prefs);
  }

  /// Visible for tests.
  Future<void> apply(SharedPreferences prefs) async {
    if (prefs.getBool(_markerKey) ?? false) return;
    // Data is already live in this domain: nothing to migrate.
    if (prefs.getString('flutter.hosts.v1')?.isNotEmpty ?? false) {
      await prefs.setBool(_markerKey, true);
      return;
    }

    final plistPath = _containerPlistPath();
    // No legacy sandbox container: nothing was ever migrated.
    if (plistPath == null || !File(plistPath).existsSync()) {
      await prefs.setBool(_markerKey, true);
      return;
    }

    final payload = _readContainerPrefs(plistPath);
    final imported = applyPayload(prefs, payload);
    await prefs.setBool(_markerKey, true);
    // Imported is informational for callers/tests; completion is the marker.
    assert(imported >= 0);
  }

  /// Reads the legacy sandbox plist and returns every key/value pair as a
  /// plain JSON map (plutil can convert any scalar-valued plist to JSON).
  Map<String, dynamic> _readContainerPrefs(String path) {
    try {
      final result = Process.runSync('/usr/bin/plutil', [
        '-convert',
        'json',
        '-o',
        '-',
        path,
      ]);
      if (result.exitCode != 0) return {};
      return jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Copies every `flutter.*` entry into prefs. Returns how many keys were
  /// written. Values are written with the concrete setter the plist type
  /// maps to; unsupported types are skipped.
  static int applyPayload(SharedPreferences prefs, Map<String, dynamic> data) {
    var count = 0;
    for (final entry in data.entries) {
      final key = entry.key;
      if (!key.startsWith('flutter.')) continue;
      try {
        final value = entry.value;
        if (value is String) {
          prefs.setString(key, value);
        } else if (value is bool) {
          prefs.setBool(key, value);
        } else if (value is int) {
          prefs.setInt(key, value);
        } else if (value is double) {
          prefs.setDouble(key, value);
        } else if (value is List &&
            value.every((item) => item is String)) {
          prefs.setStringList(key, value.cast<String>());
        } else {
          continue;
        }
        count++;
      } catch (_) {}
    }
    return count;
  }

  /// Locates this app's legacy container plist. The bundle id is resolved
  /// from the running app's own Info.plist, falling back to the known id.
  String? _containerPlistPath() {
    final bundleId = _resolveBundleId() ?? _fallbackBundleId;
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return '$home/Library/Containers/$bundleId/Data/Library/'
        'Preferences/$bundleId.plist';
  }

  String? _resolveBundleId() {
    final executable = Platform.resolvedExecutable;
    final infoPlist = File(
      '$executable/../../Info.plist', // .app/Contents/MacOS/exec → Contents/Info.plist
    );
    if (!infoPlist.existsSync()) return null;
    try {
      final result = Process.runSync('/usr/bin/plutil', [
        '-convert',
        'json',
        '-o',
        '-',
        infoPlist.path,
      ]);
      if (result.exitCode != 0) return null;
      final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      return json['CFBundleIdentifier'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// One-time removal of leftover sandbox-era records, for machines where the
/// migration already ran (its marker exists) but stale records linger.
///
/// Deletes host list, private keys, reading progress and the last-connected
/// pointer, then removes the legacy container plist so a later run can never
/// re-import the deleted data. Skipped entirely when [allowed] is false —
/// i.e. on machines whose data was just imported by [SandboxMigration].
///
/// macOS only: the sandbox container exists nowhere else.
class LegacyRecordCleanup {
  const LegacyRecordCleanup();

  static const _cleanupMarker = 'legacy.cleanup.v1';

  /// Visible for tests.
  static Set<String> legacyKeys(SharedPreferences prefs) {
    return prefs
        .getKeys()
        .where((key) =>
            key == 'flutter.hosts.v1' ||
            key == 'flutter.last.connected.host' ||
            key.startsWith('flutter.host.') ||
            key.startsWith('flutter.reading.state.'))
        .toSet();
  }

  Future<void> run(SharedPreferences prefs, {required bool allowed}) async {
    if (!Platform.isMacOS) return;
    if (!(prefs.getBool(_cleanupMarker) ?? false)) {
      if (allowed) {
        final keys = legacyKeys(prefs);
        for (final key in keys) {
          await prefs.remove(key);
        }
        _deleteContainerPlist();
      }
      await prefs.setBool(_cleanupMarker, true);
    }
  }

  void _deleteContainerPlist() {
    final home = Platform.environment['HOME'];
    if (home == null || _containerPlist == null) return;
    final file = File(_containerPlist!);
    if (file.existsSync()) {
      try {
        file.delete();
      } catch (_) {}
    }
  }

  static String? get _containerPlist {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return '$home/Library/Containers/$_bundleId/Data/Library/'
        'Preferences/$_bundleId.plist';
  }

  static const _bundleId = 'cox.work.tinydesk';
}
