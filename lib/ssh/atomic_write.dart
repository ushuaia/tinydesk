/// Replaces the remote file at [path] with [bytes] without leaving it
/// truncated: the content is written to a hidden sibling first and only
/// swapped in once it is complete.
///
/// SFTP rename cannot overwrite, so the swap moves the original aside, puts
/// the new file in place and deletes the original. If the swap fails, the
/// original is moved back. The original's permission bits are carried over.
Future<void> writeRemoteAtomically(
  String path,
  List<int> bytes, {
  required Future<int?> Function(String path) modeOf,
  required Future<void> Function(String path, List<int> bytes) writeFile,
  required Future<void> Function(String path, int mode) setMode,
  required Future<void> Function(String from, String to) rename,
  required Future<void> Function(String path) remove,
}) async {
  final slash = path.lastIndexOf('/');
  final dir = slash < 0 ? '' : path.substring(0, slash);
  final name = path.substring(slash + 1);
  final temp = '$dir/.$name.tmp';
  final backup = '$dir/.$name.bak';

  final mode = await modeOf(path);
  try {
    await writeFile(temp, bytes);
    if (mode == null) {
      await rename(temp, path);
      return;
    }
    await setMode(temp, mode);
    await _removeQuietly(remove, backup);
    await rename(path, backup);
    try {
      await rename(temp, path);
    } catch (_) {
      await rename(backup, path);
      rethrow;
    }
    await _removeQuietly(remove, backup);
  } catch (_) {
    await _removeQuietly(remove, temp);
    rethrow;
  }
}

Future<void> _removeQuietly(
  Future<void> Function(String path) remove,
  String path,
) async {
  try {
    await remove(path);
  } catch (_) {}
}
