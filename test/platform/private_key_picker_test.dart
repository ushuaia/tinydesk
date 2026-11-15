import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/platform/private_key_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pick returns file content from platform channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('opencode/file'),
      (call) async {
        expect(call.method, 'pickPrivateKey');
        return '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----';
      },
    );

    final text = await PrivateKeyPicker().pick();

    expect(text, contains('BEGIN OPENSSH PRIVATE KEY'));
  });

  test('pick returns null for empty content', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('opencode/file'),
      (call) async => '',
    );

    expect(await PrivateKeyPicker().pick(), isNull);
  });
}
