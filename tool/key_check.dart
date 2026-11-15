import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

void main() {
  final path = Platform.environment['KEY_PATH'] ?? '/tmp/phone_key';
  final pem = File(path).readAsStringSync();
  final keys = SSHKeyPair.fromPem(pem);
  for (final key in keys) {
    final encoded = key.toPublicKey().encode();
    stdout.writeln('algorithm: ${key.name}');
    stdout.writeln(
      'public   : ${SSHHostKey.getType(encoded)} ${base64Encode(encoded)}',
    );
  }
}
