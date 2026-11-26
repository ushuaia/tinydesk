import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/features/documents/file_sniff.dart';

void main() {
  test('a NUL byte marks the content as binary', () {
    expect(looksBinary(Uint8List.fromList([104, 105, 0, 10])), isTrue);
  });

  test('plain text and UTF-8 content are not binary', () {
    expect(looksBinary(Uint8List.fromList([104, 101, 108, 108, 111, 10])), isFalse);
    // "你好" in UTF-8
    expect(looksBinary(Uint8List.fromList([228, 189, 160, 229, 165, 189, 10])),
        isFalse);
  });

  test('empty content is not binary', () {
    expect(looksBinary(Uint8List(0)), isFalse);
  });
}
