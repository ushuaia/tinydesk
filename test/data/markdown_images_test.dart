import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/markdown_images.dart';

void main() {
  group('resolveMarkdownImagePath', () {
    test('resolves plain file names against the document directory', () {
      expect(resolveMarkdownImagePath('/home/u/proj', 'img.png'),
          '/home/u/proj/img.png');
      expect(resolveMarkdownImagePath('/home/u/proj/', 'img.png'),
          '/home/u/proj/img.png');
    });

    test('resolves ./ and ../ references', () {
      expect(resolveMarkdownImagePath('/home/u/proj', './assets/a.png'),
          '/home/u/proj/assets/a.png');
      expect(resolveMarkdownImagePath('/home/u/proj/sub', '../img.png'),
          '/home/u/proj/img.png');
      expect(
          resolveMarkdownImagePath('/home/u/proj/sub', '../../shared/x.png'),
          '/home/u/shared/x.png');
    });

    test('keeps absolute paths', () {
      expect(resolveMarkdownImagePath('/home/u/proj', '/var/shot.png'),
          '/var/shot.png');
    });

    test('returns null for remote and data references', () {
      expect(resolveMarkdownImagePath('/p', 'https://a.com/b.png'), isNull);
      expect(resolveMarkdownImagePath('/p', 'http://a.com/b.png'), isNull);
      expect(resolveMarkdownImagePath('/p', 'data:image/png;base64,xxx'),
          isNull);
    });

    test('decodes percent-encoded names', () {
      expect(resolveMarkdownImagePath('/home/u/proj', 'my%20pic.png'),
          '/home/u/proj/my pic.png');
    });
  });

  group('rewriteMarkdownImages', () {
    test('rewrites relative image references to the /img endpoint', () {
      final out = rewriteMarkdownImages(
        '![shot](assets/shot.png)',
        baseDir: '/home/u/proj',
        token: 'tok1',
      );
      expect(
        out,
        '![shot](/img?t=tok1&p=${_b64('/home/u/proj/assets/shot.png')})',
      );
    });

    test('keeps the title suffix', () {
      final out = rewriteMarkdownImages(
        '![shot](shot.png "a title")',
        baseDir: '/p',
        token: 'tok1',
      );
      expect(out, '![shot](/img?t=tok1&p=${_b64('/p/shot.png')} "a title")');
    });

    test('leaves remote and data references alone', () {
      final md = '''
![remote](https://a.com/b.png)
![local](local.png)
![data](data:image/png;base64,xxx)
''';
      final out = rewriteMarkdownImages(md, baseDir: '/p', token: 'tok1');
      expect(out, contains('https://a.com/b.png'));
      expect(out, contains('data:image/png;base64,xxx'));
      expect(out, contains('/img?t=tok1&p='));
    });

    test('rewrites HTML img tags', () {
      final out = rewriteMarkdownImages(
        '<img src="shot.png" alt="x">',
        baseDir: '/p',
        token: 'tok1',
      );
      expect(out, contains('/img?t=tok1&p='));
    });

    test('skips references inside code fences', () {
      final out = rewriteMarkdownImages(
        '```\n![x](y.png)\n```',
        baseDir: '/p',
        token: 't',
      );
      expect(out, isNot(contains('/img?t=t&p=')));
      expect(out, contains('y.png'));
    });
  });

  test('contentTypeForExtension maps common types', () {
    expect(contentTypeForExtension('a.png'), 'image/png');
    expect(contentTypeForExtension('a.JPG'), 'image/jpeg');
    expect(contentTypeForExtension('a.svg'), 'image/svg+xml');
    expect(contentTypeForExtension('a.bin'), 'application/octet-stream');
  });

  test('isInsideDirectory guards path escapes', () {
    expect(isInsideDirectory('/p/sub/x.png', '/p'), isTrue);
    expect(isInsideDirectory('/p', '/p'), isTrue);
    expect(isInsideDirectory('/p2/x', '/p'), isFalse);
    expect(isInsideDirectory('/other/x', '/p'), isFalse);
  });
}

String _b64(String value) {
  final encoded = base64Url.encode(value.codeUnits);
  // base64Url keeps padding; strip it the way the endpoint tolerates both.
  return encoded;
}
