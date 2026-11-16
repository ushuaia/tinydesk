import 'package:flutter/services.dart';

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

  /// On iOS and macOS, WKWebView reads cookies from its own
  /// WKHTTPCookieStore, which the Flutter cookie manager does not populate.
  /// This path writes the session cookie through the native side instead.
  Future<void> setSessionCookie(
    String name,
    String value,
    String domain,
  ) async {
    try {
      await _channel.invokeMethod<void>('setSessionCookie', {
        'name': name,
        'value': value,
        'domain': domain,
      });
    } catch (_) {}
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
