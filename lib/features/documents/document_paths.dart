import '../../data/remote_file.dart';

/// The kind label stored with a favorite, naming the reader it opens with.
String documentKind(RemoteFile file) {
  if (file.isMarkdown) return 'markdown';
  if (file.isPdf) return 'pdf';
  if (file.isCsv || file.isSpreadsheet || file.isWord) return 'office';
  if (file.isImage) return 'image';
  return 'text';
}

/// The directory containing [path].
String parentPath(String path) {
  var value = path;
  if (value.endsWith('/') && value.length > 1) {
    value = value.substring(0, value.length - 1);
  }
  final index = value.lastIndexOf('/');
  if (index <= 0) return '/';
  return value.substring(0, index);
}

/// The last segment of [path].
String baseName(String path) {
  if (path == '/' || path.isEmpty) return '/';
  final trimmed =
      path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  final slash = trimmed.lastIndexOf('/');
  return slash < 0 ? trimmed : trimmed.substring(slash + 1);
}

/// Longest known project root containing [path], so `.tinydesk` metadata
/// lands in the project rather than in an arbitrary parent directory.
String projectRootFor(
  String path, {
  required List<RemoteFile> roots,
  String fallback = '',
}) {
  String? best;
  for (final root in roots) {
    final value = root.path;
    if (value.isEmpty || value == '/') continue;
    if (path == value || path.startsWith('$value/')) {
      if (best == null || value.length > best.length) best = value;
    }
  }
  if (best != null) return best;
  if (fallback.isNotEmpty) return fallback;
  return parentPath(path);
}
