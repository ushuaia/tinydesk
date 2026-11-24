import 'package:flutter/services.dart';

/// Intercepts the macOS window close button so Flutter can decide between
/// closing the current page and confirming an app quit.
class WindowCloseHandler {
  WindowCloseHandler._();

  static const _channel = MethodChannel('opencode/window');

  static Future<void> Function()? _onCloseRequested;
  static Future<bool> Function()? _onMinimizeRequested;
  static Future<bool> Function()? _onZoomRequested;

  /// Registers the Dart-side handlers. Safe to call on every platform: the
  /// channel simply never fires where the native side is absent.
  static void register(
    Future<void> Function() handler, {
    Future<bool> Function()? onMinimizeRequested,
    Future<bool> Function()? onZoomRequested,
  }) {
    _onCloseRequested = handler;
    _onMinimizeRequested = onMinimizeRequested;
    _onZoomRequested = onZoomRequested;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'closeRequested':
          await _onCloseRequested?.call();
          return null;
        case 'minimizeRequested':
          // Returning false tells the native side to run its default
          // miniaturize (used on pages without a floating overlay).
          return await _onMinimizeRequested?.call() ?? false;
        case 'zoomRequested':
          return await _onZoomRequested?.call() ?? false;
      }
      return null;
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
