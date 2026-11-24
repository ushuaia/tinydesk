import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/core/connection_controller.dart';
import 'package:tinydesk/core/connection_state.dart';

void main() {
  test('backoff grows and caps at 30s', () {
    final backoff = Backoff();
    expect(backoff.next(0), const Duration(seconds: 1));
    expect(backoff.next(1), const Duration(seconds: 2));
    expect(backoff.next(2), const Duration(seconds: 4));
    expect(backoff.next(10), const Duration(seconds: 30));
  });

  test('initial snapshot is idle', () {
    final controller = ConnectionController();
    expect(controller.state.phase, ConnectionPhase.idle);
  });
}
