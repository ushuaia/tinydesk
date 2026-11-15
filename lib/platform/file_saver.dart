import 'package:flutter/services.dart';

/// Asks the platform to save bytes under a user-chosen location.
///
/// Returns the saved path, or `null` when the user cancels the picker.
class FileSaver {
  const FileSaver();

  static const _channel = MethodChannel('opencode/file');

  Future<String?> save({
    required String name,
    required Uint8List bytes,
  }) {
    return _channel.invokeMethod<String>('saveFile', {
      'name': name,
      'bytes': bytes,
    });
  }
}
