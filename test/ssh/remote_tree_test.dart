import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/ssh/remote_tree.dart';

/// In-memory remote filesystem that mirrors SFTP semantics: unlink only
/// works on files, rmdir only on empty directories.
class _Remote {
  _Remote(this.dirs, this.files);

  final Map<String, List<String>> dirs;
  final Set<String> files;

  Future<List<String>> listChildren(String dir) async {
    final children = dirs[dir];
    if (children == null) throw StateError('no such directory $dir');
    return List.of(children);
  }

  Future<void> removeFile(String path) async {
    if (!files.remove(path)) throw StateError('not a file $path');
    _unlinkFromParent(path);
  }

  Future<void> removeDir(String path) async {
    final children = dirs[path];
    if (children == null) throw StateError('no such directory $path');
    if (children.isNotEmpty) throw StateError('directory not empty $path');
    dirs.remove(path);
    _unlinkFromParent(path);
  }

  void _unlinkFromParent(String path) {
    final slash = path.lastIndexOf('/');
    final parent = slash <= 0 ? '/' : path.substring(0, slash);
    dirs[parent]?.remove(path);
  }

  Future<void> remove(String path) => removeRemoteTree(
        path,
        listChildren: listChildren,
        removeFile: removeFile,
        removeDir: removeDir,
      );
}

void main() {
  test('removes a directory whose children include hidden entries', () async {
    final remote = _Remote(
      {
        '/p': ['/p/d'],
        '/p/d': ['/p/d/.git', '/p/d/a.txt'],
        '/p/d/.git': ['/p/d/.git/HEAD'],
      },
      {'/p/d/a.txt', '/p/d/.git/HEAD'},
    );

    await remote.remove('/p/d');

    expect(remote.dirs.containsKey('/p/d'), isFalse);
    expect(remote.dirs.containsKey('/p/d/.git'), isFalse);
    expect(remote.files, isEmpty);
    expect(remote.dirs['/p'], isEmpty);
  });

  test('removes a single file without listing its parent', () async {
    final remote = _Remote(
      {
        '/p': ['/p/a.txt'],
      },
      {'/p/a.txt'},
    );

    await remote.remove('/p/a.txt');

    expect(remote.files, isEmpty);
    expect(remote.dirs['/p'], isEmpty);
  });
}
