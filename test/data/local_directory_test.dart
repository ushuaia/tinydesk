import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/local_directory.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tinydesk-dir-test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('lists entries, hides dotfiles, directories first then by name',
      () async {
    await File('${root.path}/b.txt').writeAsString('hello');
    await File('${root.path}/.hidden').writeAsString('secret');
    await Directory('${root.path}/Zeta').create();
    await Directory('${root.path}/alpha').create();

    final files = await listLocalDirectory(root.path);

    expect(files.map((f) => f.name), ['alpha', 'Zeta', 'b.txt']);
    expect(files.where((f) => f.isDirectory).length, 2);
    expect(files.last.size, 5);
  });

  test('treats symlinks to directories as directories', () async {
    final target = await Directory('${root.path}/real').create();
    await Link('${root.path}/link').create(target.path);

    final files = await listLocalDirectory(root.path);
    final link = files.firstWhere((f) => f.name == 'link');

    expect(link.isDirectory, isTrue);
  });

  test('skips broken symlinks instead of failing the whole listing', () async {
    await Link('${root.path}/broken').create('${root.path}/missing');
    await File('${root.path}/ok.txt').writeAsString('ok');

    final files = await listLocalDirectory(root.path);

    expect(files.map((f) => f.name), ['ok.txt']);
  });

  test('propagates permission errors so the UI can explain them', () async {
    final blocked = await Directory('${root.path}/blocked').create();
    await File('${blocked.path}/inside.txt').writeAsString('x');
    await Process.run('chmod', ['000', blocked.path]);

    try {
      await expectLater(listLocalDirectory(blocked.path), throwsA(anything));
    } finally {
      await Process.run('chmod', ['755', blocked.path]);
    }
  });
}
