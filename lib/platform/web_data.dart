import 'package:flutter/services.dart';

import '../data/workspace_session.dart';

/// Clears the WebView cookie jar so sessions from different hosts do not
/// bleed into each other. Cookies are keyed by domain (127.0.0.1), not by
/// port, so every host would otherwise share the same session.
class WebData {
  const WebData();

  static const _channel = MethodChannel('opencode/webdata');

  Future<void> clearCookies() async {
    try {
      await _channel.invokeMethod<void>('clearCookies');
    } catch (_) {}
  }

  /// The session cookie that authenticates [localPort]'s opencode server,
  /// read live from the WebView store. This is the single source of truth
  /// for native HTTP features (project roots, favorite sync).
  Future<MapEntry<String, String>?> sessionCookie(int localPort) async {
    final cookies = await sessionCookies('http://127.0.0.1:$localPort/');
    return pickSessionCookie(cookies, localPort);
  }

  /// Reads the cookies the embedded WebView currently holds for [url].
  /// Used after the in-WebView pairing login to hand the session cookie to
  /// the native HTTP client (file browser roots, favorite sync).
  Future<Map<String, String>> sessionCookies(String url) async {
    try {
      final list = await _channel.invokeListMethod<dynamic>(
        'getSessionCookies',
        {'url': url},
      );
      final cookies = <String, String>{};
      for (final entry in list ?? const []) {
        if (entry is Map) {
          final name = entry['name'];
          final value = entry['value'];
          if (name is String && value is String) cookies[name] = value;
        }
      }
      return cookies;
    } catch (_) {
      return const {};
    }
  }
}
