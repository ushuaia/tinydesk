import 'package:flutter/services.dart';

class PrivateKeyPicker {
  const PrivateKeyPicker();

  static const _channel = MethodChannel('opencode/file');

  Future<String?> pick() async {
    final text = await _channel.invokeMethod<String>('pickPrivateKey');
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }
}
