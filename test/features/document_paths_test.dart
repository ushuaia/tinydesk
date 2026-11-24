import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_paths.dart';

RemoteFile _file(String name, {String dir = '/p'}) => RemoteFile(
      name: name,
      path: '$dir/$name',
      isDirectory: false,
    );

void main() {
  test('documentKind names the reader a file opens with', () {
    expect(documentKind(_file('a.md')), 'markdown');
    expect(documentKind(_file('a.pdf')), 'pdf');
    expect(documentKind(_file('a.csv')), 'office');
    expect(documentKind(_file('a.xlsx')), 'office');
    expect(documentKind(_file('a.docx')), 'office');
    expect(documentKind(_file('a.png')), 'image');
    expect(documentKind(_file('a.txt')), 'text');
    expect(documentKind(_file('a.bin')), 'file');
  });

  test('parentPath returns the containing directory', () {
    expect(parentPath('/p/a.txt'), '/p');
    expect(parentPath('/a.txt'), '/');
    expect(parentPath('/p/dir/'), '/p');
    expect(parentPath('/'), '/');
  });

  test('baseName returns the last segment', () {
    expect(baseName('/p/a.txt'), 'a.txt');
    expect(baseName('/p/dir/'), 'dir');
    expect(baseName('/'), '/');
    expect(baseName(''), '/');
  });

  test('projectRootFor prefers the longest matching root', () {
    final roots = [
      const RemoteFile(name: 'p', path: '/p', isDirectory: true),
      const RemoteFile(name: 'app', path: '/p/app', isDirectory: true),
    ];
    expect(projectRootFor('/p/app/src/a.md', roots: roots), '/p/app');
    expect(projectRootFor('/p/other/a.md', roots: roots), '/p');
  });

  test('projectRootFor falls back to the page root, then the parent', () {
    expect(
      projectRootFor('/x/y/a.md', roots: const [], fallback: '/x'),
      '/x',
    );
    expect(
      projectRootFor('/x/y/a.md', roots: const [], fallback: ''),
      '/x/y',
    );
  });
}
