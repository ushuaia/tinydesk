import 'package:flutter/services.dart';

/// Intercepts the macOS window close button so Flutter can decide between
/// closing the current page and confirming an app quit.
class WindowCloseHandler {
  WindowCloseHandler._();

  static const _channel = MethodChannel('opencode/window');

  static Future<void> Function()? _onCloseRequested;

  /// Registers the Dart-side handler. Safe to call on every platform: the
  /// channel simply never fires where the native side is absent.
  static void register(Future<void> Function() handler) {
    _onCloseRequested = handler;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'closeRequested') {
        await _onCloseRequested?.call();
      }
    });
  }

  static void unregister() {
    _onCloseRequested = null;
    _channel.setMethodCallHandler(null);
  }

  /// Lets the native window actually close (which quits the app).
  static Future<void> confirmClose() async {
    try {
      await _channel.invokeMethod<void>('confirmClose');
    } catch (_) {}
  }
}
