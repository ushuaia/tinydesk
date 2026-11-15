import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/opencode/opencode_client.dart';

void main() {
  test('parses pair url from opencode pair output', () {
    const output = '''
  Open a link to connect. Links work once and expire in 5 minutes.

  http://127.0.0.1:49375/auth/connect/SckqOp7890Y9U_WSPrPpVw
''';
    expect(
      parsePairUrl(output),
      'http://127.0.0.1:49375/auth/connect/SckqOp7890Y9U_WSPrPpVw',
    );
  });

  test('returns null when output has no link', () {
    expect(parsePairUrl('opencode: command not found'), isNull);
  });
}
