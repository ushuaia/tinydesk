import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/opencode/opencode_client.dart';
import 'package:tinydesk/opencode/opencode_errors.dart';

void main() {
  group('resolvePairingSession', () {
    test('prefers the legacy set-cookie reply', () {
      final session = resolvePairingSession(
        baseUrl: 'http://127.0.0.1:49374',
        accessUri: Uri.parse('http://127.0.0.1:49374/auth/connect/abc'),
        setCookieHeaders: [
          'opencode-session=legacy-token; Path=/; HttpOnly; SameSite=Lax',
        ],
        responseBody: '',
        statusCode: 200,
      );
      expect(session.cookieName, 'opencode-session');
      expect(session.cookieValue, 'legacy-token');
    });

    test('builds a port-scoped cookie from the v2.3 JSON token', () {
      final session = resolvePairingSession(
        baseUrl: 'http://127.0.0.1:49374',
        accessUri: Uri.parse('http://127.0.0.1:49374/auth/connect/abc'),
        setCookieHeaders: const [],
        responseBody: '{"token":"1797393455.abcDEF"}',
        statusCode: 200,
      );
      expect(session.cookieName, 'opencode_session_49374');
      expect(session.cookieValue, '1797393455.abcDEF');
    });

    test('uses the tunnel port for the cookie name', () {
      final session = resolvePairingSession(
        baseUrl: 'http://127.0.0.1:52100',
        accessUri: Uri.parse('http://127.0.0.1:52100/auth/connect/abc'),
        setCookieHeaders: const [],
        responseBody: '{"token":"t"}',
        statusCode: 200,
      );
      expect(session.cookieName, 'opencode_session_52100');
    });

    test('throws when neither a cookie nor a token is present', () {
      expect(
        () => resolvePairingSession(
          baseUrl: 'http://127.0.0.1:49374',
          accessUri: Uri.parse('http://127.0.0.1:49374/auth/connect/abc'),
          setCookieHeaders: const [],
          responseBody: '{"error":"expired"}',
          statusCode: 401,
        ),
        throwsA(isA<PairingFailed>()),
      );
    });
  });
}
