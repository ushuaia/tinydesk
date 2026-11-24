import 'package:flutter/services.dart';

/// Intercepts the macOS window close button so Flutter can decide between
/// closing the current page and confirming an app quit.
class WindowCloseHandler {
  WindowCloseHandler._();

  static const _channel = MethodChannel('opencode/window');

  static Future<void> Function()? _onCloseRequested;
  static Future<void> Function()? _onMinimizeRequested;
  static Future<void> Function()? _onZoomRequested;

  /// Registers the Dart-side handlers. Safe to call on every platform: the
  /// channel simply never fires where the native side is absent.
  static void register(
    Future<void> Function() handler, {
    Future<void> Function()? onMinimizeRequested,
    Future<void> Function()? onZoomRequested,
  }) {
    _onCloseRequested = handler;
    _onMinimizeRequested = onMinimizeRequested;
    _onZoomRequested = onZoomRequested;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'closeRequested':
          await _onCloseRequested?.call();
        case 'minimizeRequested':
          await _onMinimizeRequested?.call();
        case 'zoomRequested':
          await _onZoomRequested?.call();
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
