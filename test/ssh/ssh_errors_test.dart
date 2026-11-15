import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/ssh/ssh_errors.dart';

void main() {
  test('maps socket errors to network unreachable', () {
    final error = mapSshException(
      const SocketExceptionLike('Connection refused'),
      host: '10.0.0.2',
      port: 22,
    );
    expect(error, isA<NetworkUnreachable>());
    expect(error.userMessage, contains('Cannot reach'));
  });

  test('maps auth failure', () {
    final error = mapSshException(
      StateError('all authentication methods failed'),
      host: '10.0.0.2',
      port: 22,
    );
    expect(error, isA<SshAuthFailed>());
  });

  test('maps host key failure', () {
    final error = mapSshException(
      Exception('host key verification failed'),
      host: '10.0.0.2',
      port: 22,
    );
    expect(error, isA<HostKeyMismatch>());
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike(this.message);
  final String message;
  @override
  String toString() => 'SocketException: $message';
}
