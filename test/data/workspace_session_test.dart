import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/workspace_session.dart';

void main() {
  group('pickSessionCookie', () {
    test('prefers the cookie of the requested port', () {
      final picked = pickSessionCookie({
        'opencode_session_49375': 'other-host',
        'opencode_session_49377': 'this-host',
      }, 49377);
      expect(picked!.key, 'opencode_session_49377');
      expect(picked.value, 'this-host');
    });

    test('ignores empty values from the wanted port', () {
      final picked = pickSessionCookie({
        'opencode_session_49377': '',
        'opencode_session_49375': 'other-host',
      }, 49377);
      // Falls back to the prefix entry rather than returning an empty value.
      expect(picked!.key, 'opencode_session_49375');
    });

    test('returns null when no session cookie exists', () {
      expect(pickSessionCookie({'oc_locale': 'en'}, 49377), isNull);
    });
  });

  group('isRestorableUrl', () {
    test('accepts pages of this host', () {
      expect(
        isRestorableUrl('http://127.0.0.1:49377/server/x/session/ses_1', 49377),
        isTrue,
      );
      expect(isRestorableUrl('http://127.0.0.1:49377/', 49377), isTrue);
    });

    test('rejects the one-time pairing link', () {
      expect(
        isRestorableUrl('http://127.0.0.1:49377/auth/connect/abc', 49377),
        isFalse,
      );
    });

    test('rejects other hosts or origins', () {
      expect(isRestorableUrl('http://127.0.0.1:49376/', 49377), isFalse);
      expect(isRestorableUrl('http://example.com/', 49377), isFalse);
      expect(isRestorableUrl(null, 49377), isFalse);
    });
  });
}
