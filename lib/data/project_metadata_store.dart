import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../ssh/tunnel_session.dart';

/// Stores app metadata inside `<project>/.tinydesk/` on the remote host.
///
/// Keeping all project-scoped metadata in one hidden folder makes it easy to
/// move between devices and keeps the project tree tidy.
///
/// When [userScope] is set (the SSH user name), data lives under
/// `<project>/.tinydesk/users/<name>/`, so several accounts that share the
/// same project do not read or overwrite each other's favorites and reading
/// progress. Pre-isolation files in `.tinydesk/` are adopted once: copied to
/// the scoped folder, then removed.
class ProjectMetadataStore {
  ProjectMetadataStore({
    required this.session,
    required this.projectRoot,
    this.userScope = '',
  });

  static const folderName = '.tinydesk';

  final TunnelSession session;
  final String projectRoot;
  final String userScope;

  String get _root => _join(projectRoot, folderName);

  String get folderPath {
    final scope = sanitizeScope(userScope);
    return scope.isEmpty ? _root : _join(_join(_root, 'users'), scope);
  }

  String pathFor(String name) => _join(folderPath, name);

  /// Location used before per-user isolation; read once to adopt the data.
  String legacyPathFor(String name) => _join(_root, name);

  /// Restricts the scope to a safe single path segment.
  static String sanitizeScope(String scope) {
    final cleaned = scope.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (cleaned == '.' || cleaned == '..') return '';
    return cleaned;
  }

  Future<Map<String, dynamic>?> readJson(String name) async {
    final current = await _readJsonAt(pathFor(name));
    if (current != null) return current;

    final legacy = await _readJsonAt(legacyPathFor(name));
    if (legacy == null) return null;

    // Adopt the shared file for this user. Only remove it once the scoped
    // copy is safely written.
    try {
      await writeJson(name, legacy);
      await session.delete(legacyPathFor(name));
    } catch (_) {}
    return legacy;
  }

  /// Returns null only when the file does not exist. Any other failure is
  /// rethrown, so callers never mistake an unreadable file for an empty one
  /// and overwrite it.
  Future<Map<String, dynamic>?> _readJsonAt(String path) async {
    final String text;
    try {
      text = await session.readText(path);
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) return null;
      rethrow;
    }
    if (text.trim().isEmpty) return null;
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('$path does not contain a JSON object');
  }

  Future<void> writeJson(String name, Map<String, dynamic> data) async {
    await session.createDirectory(folderPath);
    await session.writeText(
      pathFor(name),
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  String _join(String dir, String name) {
    if (dir.endsWith('/')) return '$dir$name';
    return '$dir/$name';
  }
}
