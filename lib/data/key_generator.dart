import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart';

class GeneratedKey {
  const GeneratedKey({
    required this.privateKeyPem,
    required this.publicKey,
  });

  final String privateKeyPem;
  final String publicKey;
}

class KeyGenerator {
  const KeyGenerator();

  Future<GeneratedKey> generate({required String comment}) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final seed = await keyPair.extractPrivateKeyBytes();
    final public = await keyPair.extractPublicKey();
    final publicBytes = Uint8List.fromList(public.bytes);
    final privateBytes = Uint8List.fromList([...seed, ...publicBytes]);

    final pair = OpenSSHEd25519KeyPair(
      publicBytes,
      privateBytes,
      comment,
    );
    final pem = pair.toPem();
    final encoded = pair.toPublicKey().encode();
    final type = SSHHostKey.getType(encoded);

    return GeneratedKey(
      privateKeyPem: pem,
      publicKey: '$type ${base64Encode(encoded)} $comment',
    );
  }
}
