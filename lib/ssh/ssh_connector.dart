import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:tinydesk/data/host.dart';

import 'ssh_errors.dart';

typedef UnknownHostKeyHandler = Future<bool> Function(String fingerprint);
typedef HostKeyChangedHandler = Future<bool> Function(
  String oldFingerprint,
  String newFingerprint,
);

class SshConnector {
  Future<SSHClient> connect(
    Host host, {
    required String privateKey,
    String? passphrase,
    required UnknownHostKeyHandler onUnknownHostKey,
    required HostKeyChangedHandler onHostKeyChanged,
  }) async {
    try {
      final socket = await SSHSocket.connect(
        host.host,
        host.port,
        timeout: const Duration(seconds: 15),
      );

      final keys = SSHKeyPair.fromPem(privateKey, passphrase);

      final client = SSHClient(
        socket,
        username: host.username,
        identities: keys,
        onVerifyHostKey: (type, fingerprintBytes) async {
          final fingerprint = utf8.decode(fingerprintBytes);
          if (host.knownHostFingerprint == null) {
            return onUnknownHostKey(fingerprint);
          }
          if (host.knownHostFingerprint == fingerprint) return true;
          return onHostKeyChanged(host.knownHostFingerprint!, fingerprint);
        },
      );

      await client.authenticated;
      return client;
    } on SshError {
      rethrow;
    } catch (error) {
      throw mapSshException(error, host: host.host, port: host.port);
    }
  }
}
