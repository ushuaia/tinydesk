import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/platform/background_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start invokes platform channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('opencode/background'),
      (call) async {
        calls.add(call);
        return true;
      },
    );

    await BackgroundTask().start();

    expect(calls.single.method, 'start');
  });

  test('stop invokes platform channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('opencode/background'),
      (call) async {
        calls.add(call);
        return true;
      },
    );

    await BackgroundTask().stop();

    expect(calls.single.method, 'stop');
  });

  test('update invokes platform channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('opencode/background'),
      (call) async {
        calls.add(call);
        return true;
      },
    );

    await BackgroundTask().update();

    expect(calls.single.method, 'update');
  });
}
