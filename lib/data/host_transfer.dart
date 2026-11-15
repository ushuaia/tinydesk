import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'host.dart';
import 'host_repository.dart';
import 'port_allocator.dart';
import 'private_key_store.dart';

/// Two-stage QR transfer for one host.
///
/// Stage 1 carries a random 256-bit key, stage 2 carries the host JSON
/// encrypted with it. The two codes are never shown at the same time, so a
/// single glance or screenshot cannot capture the whole secret, and the key
/// is true randomness — there is nothing to brute force.
class HostTransferData {
  const HostTransferData({
    required this.name,
    required this.address,
    required this.port,
    required this.username,
    required this.remotePort,
    required this.autoStart,
    required this.privateKey,
    required this.passphrase,
  });

  final String name;
  final String address;
  final int port;
  final String username;
  final int remotePort;
  final bool autoStart;
  final String privateKey;
  final String? passphrase;

  factory HostTransferData.fromHost(
    Host host, {
    required String privateKey,
    required String? passphrase,
  }) {
    return HostTransferData(
      name: host.name,
      address: host.host,
      port: host.port,
      username: host.username,
      remotePort: host.remotePort,
      autoStart: host.autoStartServer,
      privateKey: privateKey,
      passphrase: passphrase,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'port': port,
        'username': username,
        'remotePort': remotePort,
        'autoStart': autoStart,
        'privateKey': privateKey,
        'passphrase': passphrase,
      };

  factory HostTransferData.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final address = json['address'];
    final username = json['username'];
    final privateKey = json['privateKey'];
    if (name is! String ||
        address is! String ||
        username is! String ||
        privateKey is! String) {
      throw const HostTransferFormatError('缺少主机字段');
    }
    final port = json['port'];
    final remotePort = json['remotePort'];
    if (port is! int || remotePort is! int) {
      throw const HostTransferFormatError('端口字段无效');
    }
    return HostTransferData(
      name: name,
      address: address,
      port: port,
      username: username,
      remotePort: remotePort,
      autoStart: json['autoStart'] as bool? ?? true,
      privateKey: privateKey,
      passphrase: json['passphrase'] as String?,
    );
  }
}

const _keyType = 'tinydesk.hosts.key';
const _envelopeType = 'tinydesk.hosts.enc';
const _payloadType = 'tinydesk.hosts';
const _aadPrefix = 'tinydesk.hosts.enc/v1';
const _nonceLength = 12;
const _macLength = 16;
const _defaultValidity = Duration(minutes: 15);

final _aes = AesGcm.with256bits();

/// Raised when a stage belongs to a different transfer.
class HostTransferMismatchError implements Exception {
  const HostTransferMismatchError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Raised for malformed or wrong-type payloads.
class HostTransferFormatError implements Exception {
  const HostTransferFormatError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Raised when the transfer validity window has passed.
class HostTransferExpiredError implements Exception {
  const HostTransferExpiredError();

  @override
  String toString() => '二维码已过期，请在源设备重新导出';
}

/// Progress reported by [HostTransferReceiver.receive].
enum HostTransferStep {
  waitingForKey,
  waitingForPayload,
  ready,
}

/// The two QR texts shown one after another by the exporting device.
class HostTransferStages {
  const HostTransferStages({required this.keyStage, required this.payloadStage});

  final String keyStage;
  final String payloadStage;
}

/// Builds both stage payloads for one host. The content code expires after
/// [validity] (embedded in the encrypted payload, checked on the receiving
/// side) so saved screenshots eventually go dead.
Future<HostTransferStages> createHostTransferStages(
  HostTransferData data, {
  DateTime? expiresAt,
  Duration validity = _defaultValidity,
}) async {
  final keyBytes = _randomBytes(32);
  final keyId = _randomBytes(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  final keyStage = jsonEncode({
    'v': 1,
    'type': _keyType,
    'keyId': keyId,
    'key': base64Encode(keyBytes),
  });

  final payload = jsonEncode({
    'v': 1,
    'type': _payloadType,
    'expiresAt':
        (expiresAt ?? DateTime.now().add(validity)).toUtc().toIso8601String(),
    'hosts': [data.toJson()],
  });

  final nonce = _aes.newNonce();
  final box = await _aes.encrypt(
    utf8.encode(payload),
    secretKey: SecretKey(keyBytes),
    nonce: nonce,
    aad: utf8.encode('$_aadPrefix$keyId'),
  );

  final payloadStage = jsonEncode({
    'v': 1,
    'type': _envelopeType,
    'keyId': keyId,
    'box': base64Encode(box.concatenation()),
  });

  return HostTransferStages(keyStage: keyStage, payloadStage: payloadStage);
}

/// Receiving-side state machine: feed it the scanned codes in any order,
/// and it reports progress until both stages match up.
class HostTransferReceiver {
  String? _keyId;
  Uint8List? _keyBytes;
  Map<String, dynamic>? _payloadEnvelope;

  /// Accepts one scanned code and returns the new progress.
  ///
  /// Throws [HostTransferMismatchError] when the code belongs to another
  /// transfer and [HostTransferFormatError] for garbage input.
  HostTransferStep receive(String qrText) {
    final Object? envelope;
    try {
      envelope = jsonDecode(qrText);
    } catch (_) {
      throw const HostTransferFormatError('二维码内容无法识别');
    }
    if (envelope is! Map<String, dynamic>) {
      throw const HostTransferFormatError('二维码内容无法识别');
    }

    final type = envelope['type'];
    final keyId = envelope['keyId'];
    if (keyId is! String) {
      throw const HostTransferFormatError('二维码缺少传输标识');
    }
    if (_keyId != null && _keyId != keyId) {
      throw HostTransferMismatchError(
          '这个二维码与已接收的不匹配，请扫描同一台主机的另一张二维码');
    }

    if (type == _keyType) {
      final key = envelope['key'];
      if (key is! String) {
        throw const HostTransferFormatError('二维码内容不完整');
      }
      final bytes = base64Decode(key);
      if (bytes.length != 32) {
        throw const HostTransferFormatError('二维码内容不完整');
      }
      _keyId = keyId;
      _keyBytes = bytes;
      return _payloadEnvelope == null
          ? HostTransferStep.waitingForPayload
          : HostTransferStep.ready;
    }

    if (type == _envelopeType) {
      final box = envelope['box'];
      if (box is! String) {
        throw const HostTransferFormatError('二维码内容不完整');
      }
      _keyId = keyId;
      _payloadEnvelope = envelope;
      return _keyBytes == null
          ? HostTransferStep.waitingForKey
          : HostTransferStep.ready;
    }

    throw const HostTransferFormatError('二维码格式不识别');
  }

  /// Whether the key stage has been received.
  bool get hasKey => _keyBytes != null;

  /// Whether the content stage has been received.
  bool get hasPayload => _payloadEnvelope != null;

  /// Whether both stages were received.
  bool get isReady =>
      _keyBytes != null && _payloadEnvelope != null;

  /// Decrypts and returns the transferred host once both stages arrived.
  Future<HostTransferData> complete() async {
    if (_keyBytes == null || _payloadEnvelope == null) {
      throw const HostTransferFormatError('还需要扫描另一张二维码');
    }
    final boxBytes = base64Decode(_payloadEnvelope!['box'] as String);
    if (boxBytes.length < _nonceLength + _macLength) {
      throw const HostTransferFormatError('二维码内容不完整');
    }
    final box = SecretBox(
      boxBytes.sublist(_nonceLength, boxBytes.length - _macLength),
      nonce: boxBytes.sublist(0, _nonceLength),
      mac: Mac(boxBytes.sublist(boxBytes.length - _macLength)),
    );

    final List<int> clear;
    try {
      clear = await _aes.decrypt(
        box,
        secretKey: SecretKey(_keyBytes!),
        aad: utf8.encode('$_aadPrefix$_keyId'),
      );
    } on SecretBoxAuthenticationError {
      throw const HostTransferFormatError('两张二维码不匹配，请重新导出');
    } catch (_) {
      throw const HostTransferFormatError('二维码无法解密');
    }

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } catch (_) {
      throw const HostTransferFormatError('二维码内容无法识别');
    }
    if (payload['type'] != _payloadType) {
      throw const HostTransferFormatError('二维码格式不识别');
    }

    final expiresRaw = payload['expiresAt'];
    final expiresAt =
        expiresRaw is String ? DateTime.tryParse(expiresRaw) : null;
    if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
      throw const HostTransferExpiredError();
    }

    final hosts = payload['hosts'];
    if (hosts is! List || hosts.isEmpty) {
      throw const HostTransferFormatError('二维码中没有主机');
    }
    return HostTransferData.fromJson(
      Map<String, dynamic>.from(hosts.first as Map),
    );
  }
}

/// Imports one host, matching an existing entry by address+port+user.
///
/// The local tunnel port is not part of the transfer: new hosts get a free
/// port allocated locally and matched hosts keep theirs (the session cookie
/// depends on it).
Future<Host> importHostFromTransfer(
  HostTransferData data, {
  required HostRepository repository,
  required PrivateKeyStore keyStore,
}) async {
  final hosts = await repository.all();
  final existing = hosts.where((h) {
    return h.type == 'ssh' &&
        h.host == data.address &&
        h.port == data.port &&
        h.username == data.username;
  }).firstOrNull;

  final id = existing?.id ?? const Uuid().v4();
  final host = Host(
    id: id,
    name: data.name,
    type: 'ssh',
    host: data.address,
    port: data.port,
    username: data.username,
    privateKeyRef: 'host.$id.privateKey',
    hasPassphrase: data.passphrase != null,
    remotePort: data.remotePort,
    localPort: existing?.localPort ?? PortAllocator().nextAvailable(hosts),
    autoStartServer: data.autoStart,
    knownHostFingerprint: existing?.knownHostFingerprint,
    lastConnectedAt: existing?.lastConnectedAt,
  );

  await keyStore.save(id, data.privateKey, data.passphrase);
  await repository.upsert(host);
  return host;
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}
