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
}
