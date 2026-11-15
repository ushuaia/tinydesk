import 'package:flutter/services.dart';

/// Tells the native layer which language its own UI (scan window, file
/// panels, notifications) should use.
class NativeLanguage {
  NativeLanguage._();

  static const _channel = MethodChannel('tinydesk/language');

  static Future<void> sync(String code) async {
    try {
      await _channel.invokeMethod('set', {'lang': code});
    } on PlatformException {
      // Native side is optional (e.g. unsupported platform) — ignore.
    } on MissingPluginException {
      // No native handler on this platform — ignore.
    }
  }
}
