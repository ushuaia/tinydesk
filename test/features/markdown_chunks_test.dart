import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/features/documents/markdown_chunks.dart';

void main() {
  test('splits by top-level headings', () {
    const text = '# One\n\ntext\n\n## Two\n\nmore';
    final chunks = splitMarkdown(text);

    expect(chunks.length, 2);
    expect(chunks.first, contains('# One'));
    expect(chunks.last, contains('## Two'));
  });

  test('does not split inside fenced code blocks', () {
    const text = '# One\n\n```\n# not a heading\n## not a heading\n```\n';
    final chunks = splitMarkdown(text);

    expect(chunks.length, 1);
    expect(chunks.single, contains('# not a heading'));
  });

  test('splits large blocks without headings', () {
    final text = List.generate(200, (i) => 'line $i').join('\n');
    final chunks = splitMarkdown(text, maxChunk: 200);

    expect(chunks.length, greaterThan(1));
    expect(chunks.join(), contains('line 199'));
  });
}
