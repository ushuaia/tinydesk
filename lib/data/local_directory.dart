import 'dart:io';

import 'remote_file.dart';

/// Lists a local directory with the same shape the remote explorer expects.
///
/// - sorts directories first, then case-insensitive by name
/// - treats symlinks that point at directories as directories
/// - skips broken symlinks instead of failing the whole listing
///
/// Errors (for example macOS privacy protection on Documents/Desktop) are
/// propagated so the caller can tell the user what happened.
Future<List<RemoteFile>> listLocalDirectory(String path) async {
  final files = <RemoteFile>[];
  await for (final entity in Directory(path).list(followLinks: false)) {
    final name = entity.path.split('/').last;
    try {
      // Follow symlinks here: a link whose target is gone has to be skipped.
      final stat = FileStat.statSync(entity.path);
      if (stat.type == FileSystemEntityType.notFound) continue;
      files.add(
        RemoteFile(
          name: name,
          path: entity.path,
          isDirectory: stat.type == FileSystemEntityType.directory,
          size: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    } catch (_) {
      // Unreadable entry: hide just this row.
    }
  }
  files.sort((a, b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return files;
}
