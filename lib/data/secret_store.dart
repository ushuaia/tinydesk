import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform secure storage for secrets (SSH keys, passphrases).
///
/// macOS/iOS use the Keychain, Android uses the Keystore-backed
/// EncryptedSharedPreferences. HarmonyOS is served by [HarmonySecretStore],
/// which talks to the Asset Store Kit through a native plugin.
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            (Platform.isMacOS
                // The data-protection keychain needs a provisioning profile
                // (keychain-access-groups). Ad-hoc builds fall back to the
                // legacy keychain, which works without entitlements.
                ? const FlutterSecureStorage(
                    mOptions: MacOsOptions(
                      usesDataProtectionKeychain: false,
                    ),
                  )
                : const FlutterSecureStorage());

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// macOS: the app's own keychain channel writes items with an ACL that lets
/// any application read them, so reads never prompt. Items created by
/// flutter_secure_storage inherit the creating signature in their ACL; macOS
/// then asks twice (item + its protected key) whenever the app is re-signed.
/// They are copied over on first read.
class MacOsSecretStore implements SecretStore {
  const MacOsSecretStore();

  static const _channel = MethodChannel('opencode/secure');
  static const FlutterSecureStorage _legacy = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read(String key) async {
    try {
      final value = await _channel.invokeMethod<String>('read', {'key': key});
      if (value != null) return value;
    } catch (_) {}
    // One-time migration from the flutter_secure_storage item.
    final old = await _legacy.read(key: key);
    if (old != null) {
      try {
        await _channel.invokeMethod<void>('write', {'key': key, 'value': old});
      } catch (_) {}
    }
    return old;
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
    } catch (_) {
      await _legacy.write(key: key, value: value);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _channel.invokeMethod<void>('delete', {'key': key});
    } catch (_) {}
    await _legacy.delete(key: key);
  }
}

/// HarmonyOS implementation backed by `@ohos.security.asset`.
class HarmonySecretStore implements SecretStore {
  const HarmonySecretStore();

  static const _channel = MethodChannel('opencode/secure');

  @override
  Future<String?> read(String key) =>
      _channel.invokeMethod<String>('read', {'key': key});

  @override
  Future<void> write(String key, String value) =>
      _channel.invokeMethod<void>('write', {'key': key, 'value': value});

  @override
  Future<void> delete(String key) =>
      _channel.invokeMethod<void>('delete', {'key': key});
}

/// Only used under `flutter test`, where no platform channels exist and a
/// real secure store would keep a pending platform message alive forever.
///
/// Entries live under a `secure.` prefix so the legacy-migration code (which
/// clears `host.*` keys) cannot delete what this store just wrote.
class SharedPreferencesSecretStore implements SecretStore {
  const SharedPreferencesSecretStore();

  static String _name(String key) => 'secure.$key';

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_name(key));
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_name(key), value);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_name(key));
  }
}

/// HarmonyOS reports `ohos` from `dart:io`; other targets use the
/// `flutter_secure_storage` federated implementations.
SecretStore createSecretStore() {
  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    return const SharedPreferencesSecretStore();
  }
  if (Platform.operatingSystem == 'ohos') return const HarmonySecretStore();
  if (Platform.isMacOS) return const MacOsSecretStore();
  return FlutterSecureSecretStore();
}
