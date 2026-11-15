import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';

void main() {
  test('matches the exact file', () {
    expect(documentLivesUnder('/p/a.txt', '/p/a.txt'), isTrue);
  });

  test('matches a file inside a deleted directory', () {
    expect(documentLivesUnder('/p/dir/a.txt', '/p/dir'), isTrue);
    expect(documentLivesUnder('/p/dir/sub/a.txt', '/p/dir'), isTrue);
  });

  test('ignores siblings and other prefixes', () {
    expect(documentLivesUnder('/p/other/a.txt', '/p/dir'), isFalse);
    expect(documentLivesUnder('/p2/a.txt', '/p'), isFalse);
    expect(documentLivesUnder('/p/a.txt', '/p/a.txt.bak'), isFalse);
  });
}
