import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/data/key_generator.dart';
import 'package:tinydesk/data/private_key_store.dart';
import 'package:tinydesk/features/hosts/host_form_page.dart';

class FakeKeyGenerator extends KeyGenerator {
  @override
  Future<GeneratedKey> generate({required String comment}) async {
    return GeneratedKey(
      privateKeyPem:
          '-----BEGIN OPENSSH PRIVATE KEY-----\nfake\n-----END OPENSSH PRIVATE KEY-----',
      publicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFake $comment',
    );
  }
}

Host buildHost() => Host(
      id: 'h1',
      name: 'dev box',
      host: '10.0.0.2',
      port: 2022,
      username: 'duan',
      remotePort: 49374,
      localPort: 49375,
      autoStartServer: true,
    );

void main() {
  testWidgets('rejects empty host', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HostFormPage()));

    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Enter the host address'), findsOneWidget);
    expect(find.text('Please fix the errors in the form'), findsOneWidget);
  });

  test('rejects ppk private key', () {
    expect(
      PrivateKeyStore.isValidKey('PuTTY-User-Key-File-3: ssh-ed25519'),
      isFalse,
    );
  });

  test('rejects empty private key', () {
    expect(PrivateKeyStore.isValidKey(''), isFalse);
  });

  testWidgets('prefills fields in edit mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HostFormPage(initialHost: buildHost())),
    );

    expect(find.text('Edit host'), findsOneWidget);
    expect(find.text('dev box'), findsOneWidget);
    expect(find.text('10.0.0.2'), findsOneWidget);
    expect(find.text('2022'), findsOneWidget);
    expect(find.text('duan'), findsOneWidget);
  });

  testWidgets('generates key and shows public key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HostFormPage(keyGenerator: FakeKeyGenerator()),
      ),
    );

    await tester.ensureVisible(find.text('Generate key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate key'));
    await tester.pumpAndSettle();

    expect(find.text('Generate new key'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Public key (copied to clipboard)'), findsOneWidget);
    expect(find.textContaining('ssh-ed25519'), findsOneWidget);
  });
}
