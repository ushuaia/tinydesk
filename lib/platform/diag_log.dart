import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small rotating log that survives release builds, where debugPrint output
/// is invisible. Everything printed through [debugPrint] is mirrored here
/// (see main.dart), so a user can export the last few hundred lines after a
/// problem instead of only being able to say "it broke".
class DiagLog {
  DiagLog._();

  static const _maxBytes = 512 * 1024;
  static File? _file;
  static Future<File?>? _opening;

  static File? get file => _file;

  /// Appends one timestamped line, trimming the file when it grows past the
  /// cap. Never throws.
  static Future<void> write(String message) async {
    try {
      final file = await _ensureFile();
      if (file == null) return;
      if (file.lengthSync() > _maxBytes) {
        final content = file.readAsStringSync();
        final keep = content.length ~/ 2;
        file.writeAsStringSync(content.substring(content.length - keep));
      }
      final stamp = DateTime.now().toIso8601String().substring(11, 23);
      file.writeAsStringSync('$stamp $message\n',
          mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  /// Returns the log file for exporting, or null when unavailable.
  static Future<File?> exportable() async {
    final file = await _ensureFile();
    if (file == null || !file.existsSync()) return null;
    return file;
  }

  static Future<File?> _ensureFile() async {
    if (_file != null) return _file;
    _opening ??= _open();
    _file = await _opening;
    return _file;
  }

  static Future<File?> _open() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!logDir.existsSync()) logDir.createSync(recursive: true);
      final file = File('${logDir.path}/tinydesk.log');
      if (!file.existsSync()) file.writeAsStringSync('', flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }
}
