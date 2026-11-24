/// Removes [path] from a remote filesystem, recursing into directories.
///
/// [listChildren] must return every entry in a directory, hidden ones
/// included; otherwise a directory holding `.git` or `.tinydesk` can never be
/// emptied and its rmdir fails after its visible children are already gone.
Future<void> removeRemoteTree(
  String path, {
  required Future<List<String>> Function(String dir) listChildren,
  required Future<void> Function(String path) removeFile,
  required Future<void> Function(String path) removeDir,
}) async {
  try {
    await removeFile(path);
    return;
  } catch (_) {}
  try {
    await removeDir(path);
    return;
  } catch (_) {}
  for (final child in await listChildren(path)) {
    await removeRemoteTree(
      child,
      listChildren: listChildren,
      removeFile: removeFile,
      removeDir: removeDir,
    );
  }
  await removeDir(path);
}
