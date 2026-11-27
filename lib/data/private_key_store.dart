import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secret_store.dart';

/// 私钥存储。
///
/// macOS/iOS 使用 Keychain，Android 使用 Keystore 加密的
/// EncryptedSharedPreferences，鸿蒙使用 Asset Store Kit（系统安全存储）。
///
/// 早期版本把私钥写在 SharedPreferences 里；首次读写时会自动迁移到安全
/// 存储并删除旧键。如果安全存储不可用，读取会回退到旧位置，保证连接不中断。
class PrivateKeyStore {
  PrivateKeyStore([SecretStore? store])
      : _store = store ?? createSecretStore();

  final SecretStore _store;
  Future<void>? _migration;

  /// Keys already fetched during this run. A connection sequence asks for
  /// the same key several times (connect, document tunnel, reconnect) and
  /// every Keychain read can be slow or prompt for authorisation, so cache
  /// the result. `save`/`delete` keep the cache in sync.
  final Map<String, (String, String?)> _cache = {};
  final Map<String, Future<(String, String?)?>> _inflight = {};

  static const _prefix = 'host.';
  // The macOS keychain can prompt for authorisation (e.g. after a rebuild
  // changes the ad-hoc signature); the user needs time to type a password,
  // so this must not be a short timeout.
  static const _secureTimeout = Duration(seconds: 60);
  static const _keySuffix = '.privateKey';
  static const _passSuffix = '.passphrase';

  // Items written by this build carry the current (stable) signature in
  // their ACL, so reading them never prompts. The unprefixed items were
  // created by older ad-hoc builds and are only read once for migration.
  static const _currentPrefix = 'v2.';

  String _keyName(String hostId) => '$_prefix$hostId$_keySuffix';

  String _passName(String hostId) => '$_prefix$hostId$_passSuffix';

  static bool isValidKey(String pem, [String? passphrase]) {
    if (pem.trim().isEmpty) return false;
    try {
      return SSHKeyPair.fromPem(pem, passphrase).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> save(
    String hostId,
    String privateKey,
    String? passphrase,
  ) async {
    await _ensureMigrated();
    try {
      await _store
          .write(_currentPrefix + _keyName(hostId), privateKey)
          .timeout(_secureTimeout);
      if (passphrase != null && passphrase.isNotEmpty) {
        await _store
            .write(_currentPrefix + _passName(hostId), passphrase)
            .timeout(_secureTimeout);
      } else {
        await _store
            .delete(_currentPrefix + _passName(hostId))
            .timeout(_secureTimeout);
      }
      await _clearLegacy(hostId);
      _remember(hostId, privateKey, passphrase);
    } catch (_) {
      // Secure storage unavailable (tests, unsupported platform): keep the
      // app usable by falling back to the old sandboxed storage.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyName(hostId), privateKey);
      if (passphrase != null && passphrase.isNotEmpty) {
        await prefs.setString(_passName(hostId), passphrase);
      } else {
        await prefs.remove(_passName(hostId));
      }
      _remember(hostId, privateKey, passphrase);
    }
  }

  void _remember(String hostId, String privateKey, String? passphrase) {
    _cache[hostId] = (
      privateKey,
      passphrase != null && passphrase.isNotEmpty ? passphrase : null,
    );
  }

  Future<(String, String?)?> read(
    String hostId, {
    bool hasPassphrase = true,
  }) {
    final cached = _cache[hostId];
    if (cached != null) return Future.value(cached);
    // Two entry points (connect + document tunnel, or a double tap) must not
    // start two Keychain lookups: macOS would prompt twice.
    final pending = _inflight[hostId];
    if (pending != null) return pending;
    final future = _read(hostId, hasPassphrase: hasPassphrase);
    _inflight[hostId] = future;
    return future.whenComplete(() => _inflight.remove(hostId));
  }

  Future<(String, String?)?> _read(
    String hostId, {
    required bool hasPassphrase,
  }) async {
    await _ensureMigrated();
    final currentKey = _currentPrefix + _keyName(hostId);
    var key = await _readSecret(currentKey);
    String? passphrase;
    if (key == null) {
      // Legacy item from an ad-hoc build: read it once (may prompt), then
      // copy it under the current signature so it never prompts again.
      key = await _readSecret(_keyName(hostId));
      if (key == null) {
        return null;
      }
      // Hosts without a passphrase skip the second lookup entirely.
      if (hasPassphrase) {
        passphrase = await _readSecret(_passName(hostId));
      }
      try {
        await _store.write(currentKey, key).timeout(_secureTimeout);
        if (passphrase != null && passphrase.isNotEmpty) {
          await _store
              .write(_currentPrefix + _passName(hostId), passphrase)
              .timeout(_secureTimeout);
        }
      } catch (error) {
          debugPrint('[keychain] migrate failed $currentKey: $error');
      }
    } else if (hasPassphrase) {
      passphrase = await _readSecret(_currentPrefix + _passName(hostId));
    }
    final pair = (key, passphrase);
    _cache[hostId] = pair;
    return pair;
  }

  Future<void> delete(String hostId) async {
    _cache.remove(hostId);
    await _ensureMigrated();
    try {
      await _store
          .delete(_currentPrefix + _keyName(hostId))
          .timeout(_secureTimeout);
      await _store
          .delete(_currentPrefix + _passName(hostId))
          .timeout(_secureTimeout);
    } catch (_) {}
    await _clearLegacy(hostId);
  }

  Future<void> _clearLegacy(String hostId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyName(hostId));
      await prefs.remove(_passName(hostId));
    } catch (_) {}
  }

  /// Migrates every legacy key found in SharedPreferences.
  ///
  /// Called once at startup so plaintext keys do not linger for hosts the
  /// user never touches again.
  Future<void> migrateAll() => _ensureMigrated();

  Future<void> _ensureMigrated() => _migration ??= _migrateLegacyKeys();

  /// Moves entries written by older versions out of SharedPreferences.
  /// Each entry is only removed after the secure write succeeded.
  Future<void> _migrateLegacyKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getKeys().where(
            (name) =>
                name.startsWith(_prefix) &&
                (name.endsWith(_keySuffix) || name.endsWith(_passSuffix)),
          );
      for (final name in legacy.toList()) {
        final value = prefs.getString(name);
        if (value == null) continue;
        try {
          await _store
              .write(_currentPrefix + name, value)
              .timeout(_secureTimeout);
          await prefs.remove(name);
        } catch (_) {
          // Keep the plaintext entry so a later attempt can migrate it.
        }
      }
    } catch (_) {}
  }

  Future<String?> _readSecret(String name) async {
    try {
      final value = await _store.read(name).timeout(_secureTimeout);
      if (value != null) return value;
    } catch (_) {}
    // Fallback for platforms without a working secure store.
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(name);
    } catch (_) {
      return null;
    }
  }
}
