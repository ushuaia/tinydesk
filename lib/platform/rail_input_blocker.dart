import 'dart:io';

import 'package:flutter/services.dart';

/// macOS-only: while the tree panel overlays the content, Flutter overlays
/// cannot receive mouse events over the WebView platform view. This native
/// interceptor swallows clicks/scroll-wheel inside the content rectangle and
/// notifies Dart, so the panel closes instead of the page reacting.
class RailInputBlocker {
  RailInputBlocker._();

  static const _channel = MethodChannel('opencode/input');

  static VoidCallback? _current;

  static void register(VoidCallback onIntercepted) {
    _current = onIntercepted;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'intercepted') onIntercepted();
    });
  }

  /// Clears the handler only when [callback] is still the registered one.
  static void unregisterIf(VoidCallback callback) {
    if (!identical(_current, callback)) return;
    _current = null;
    unregister();
  }

  static Future<void> setBlocking({
    required bool blocking,
    double left = 0,
    double top = 0,
  }) async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('setBlocking', {
        'blocking': blocking,
        'left': left,
        'top': top,
      });
    } catch (_) {}
  }

  static void unregister() {
    _channel.setMethodCallHandler(null);
  }
}
