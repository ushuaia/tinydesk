import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/ssh/atomic_write.dart';

/// In-memory filesystem with SFTP rename semantics: renaming onto an existing
/// path fails instead of replacing it.
class _Fs {
  final Map<String, List<int>> files = {};
  final Map<String, int> modes = {};
  String? failWriteOn;
  String? failRenameFrom;

  Future<int?> modeOf(String path) async => modes[path];

  Future<void> writeFile(String path, List<int> bytes) async {
    if (path == failWriteOn) throw StateError('disk full');
    files[path] = List.of(bytes);
    modes.putIfAbsent(path, () => 420);
  }

  Future<void> setMode(String path, int mode) async {
    if (!files.containsKey(path)) throw StateError('no such file $path');
    modes[path] = mode;
  }

  Future<void> rename(String from, String to) async {
    if (!files.containsKey(from)) throw StateError('no such file $from');
    if (files.containsKey(to) || from == failRenameFrom) {
      throw StateError('cannot rename onto $to');
    }
    files[to] = files.remove(from)!;
    modes[to] = modes.remove(from) ?? 420;
  }

  Future<void> remove(String path) async {
    if (files.remove(path) == null) throw StateError('no such file $path');
    modes.remove(path);
  }

  Future<void> write(String path, List<int> bytes) => writeRemoteAtomically(
        path,
        bytes,
        modeOf: modeOf,
        writeFile: writeFile,
        setMode: setMode,
        rename: rename,
        remove: remove,
      );
}

void main() {
  test('writes a new file and leaves no temporary files behind', () async {
    final fs = _Fs();

    await fs.write('/p/a.md', [104, 105]);

    expect(fs.files.keys, ['/p/a.md']);
    expect(fs.files['/p/a.md'], [104, 105]);
  });

  test('replaces an existing file and keeps its permissions', () async {
    final fs = _Fs()
      ..files['/p/secret.json'] = [1]
      ..modes['/p/secret.json'] = 384;

    await fs.write('/p/secret.json', [2, 3]);

    expect(fs.files.keys, ['/p/secret.json']);
    expect(fs.files['/p/secret.json'], [2, 3]);
    expect(fs.modes['/p/secret.json'], 384);
  });

  test('a failed temporary write leaves the original untouched', () async {
    final fs = _Fs()..files['/p/a.md'] = [1, 2, 3];
    fs.failWriteOn = '/p/.a.md.tmp';

    await expectLater(
      () => fs.write('/p/a.md', [9]),
      throwsA(isA<StateError>()),
    );

    expect(fs.files['/p/a.md'], [1, 2, 3]);
    expect(fs.files.keys, ['/p/a.md']);
  });

  test('a failed final rename restores the original content', () async {
    final fs = _Fs()..files['/p/a.md'] = [1, 2, 3];
    fs.failRenameFrom = '/p/.a.md.tmp';

    await expectLater(
      () => fs.write('/p/a.md', [9]),
      throwsA(isA<StateError>()),
    );

    expect(fs.files['/p/a.md'], [1, 2, 3]);
    expect(fs.files.keys, ['/p/a.md']);
  });
}
