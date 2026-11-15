import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/key_generator.dart';

void main() {
  test('generates a valid ed25519 key pair with comment', () async {
    final key = await KeyGenerator().generate(comment: 'ss-code@test');

    expect(key.privateKeyPem, contains('BEGIN OPENSSH PRIVATE KEY'));
    expect(key.privateKeyPem, contains('END OPENSSH PRIVATE KEY'));
    expect(key.publicKey, startsWith('ssh-ed25519 '));
    expect(key.publicKey, endsWith('ss-code@test'));

    final pairs = SSHKeyPair.fromPem(key.privateKeyPem);
    expect(pairs, isNotEmpty);

    final encoded = pairs.first.toPublicKey().encode();
    final expected =
        '${SSHHostKey.getType(encoded)} ${base64Encode(encoded)}';
    expect(key.publicKey, startsWith(expected));
  });

  test('generates different keys on each call', () async {
    final a = await KeyGenerator().generate(comment: 'a');
    final b = await KeyGenerator().generate(comment: 'b');

    expect(a.publicKey, isNot(equals(b.publicKey)));
  });
}
