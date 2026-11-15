import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/data/host_repository.dart';
import 'package:tinydesk/data/host_store.dart';
import 'package:tinydesk/data/host_transfer.dart';
import 'package:tinydesk/data/private_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

HostTransferData _host() => const HostTransferData(
      name: 'dev box',
      address: '192.0.2.10',
      port: 22,
      username: 'duan',
      remotePort: 49374,
      autoStart: true,
      privateKey:
          '-----BEGIN OPENSSH PRIVATE KEY-----\nAAAA\n-----END OPENSSH PRIVATE KEY-----',
      passphrase: 'secret',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('stage payloads', () {
    test('neither stage contains plaintext host data', () async {
      final stages = await createHostTransferStages(_host());

      expect(stages.keyStage.contains('192.0.2.10'), isFalse);
      expect(stages.keyStage.contains('PRIVATE KEY'), isFalse);
      expect(stages.payloadStage.contains('192.0.2.10'), isFalse);
      expect(stages.payloadStage.contains('PRIVATE KEY'), isFalse);
    });

    test('stages carry the same key id', () async {
      final stages = await createHostTransferStages(_host());
      final keyEnvelope =
          jsonDecode(stages.keyStage) as Map<String, dynamic>;
      final payloadEnvelope =
          jsonDecode(stages.payloadStage) as Map<String, dynamic>;

      expect(keyEnvelope['type'], 'tinydesk.hosts.key');
      expect(payloadEnvelope['type'], 'tinydesk.hosts.enc');
      expect(keyEnvelope['keyId'], payloadEnvelope['keyId']);
    });
  });

  group('receiver', () {
    test('completes after scanning both stages in order', () async {
      final stages = await createHostTransferStages(_host());
      final receiver = HostTransferReceiver();

      expect(receiver.receive(stages.keyStage), HostTransferStep.waitingForPayload);
      expect(receiver.receive(stages.payloadStage), HostTransferStep.ready);

      final host = await receiver.complete();
      expect(host.name, 'dev box');
      expect(host.address, '192.0.2.10');
      expect(host.username, 'duan');
      expect(host.privateKey, contains('OPENSSH PRIVATE KEY'));
      expect(host.passphrase, 'secret');
    });

    test('works when the content code is scanned first', () async {
      final stages = await createHostTransferStages(_host());
      final receiver = HostTransferReceiver();

      expect(receiver.receive(stages.payloadStage),
          HostTransferStep.waitingForKey);
      expect(receiver.receive(stages.keyStage), HostTransferStep.ready);

      final host = await receiver.complete();
      expect(host.address, '192.0.2.10');
    });

    test('rejects a stage from a different transfer', () async {
      final stagesA = await createHostTransferStages(_host());
      final stagesB = await createHostTransferStages(
        const HostTransferData(
          name: 'other',
          address: '192.0.2.11',
          port: 22,
          username: 'duan',
          remotePort: 49374,
          autoStart: true,
          privateKey:
              '-----BEGIN OPENSSH PRIVATE KEY-----\nBBBB\n-----END OPENSSH PRIVATE KEY-----',
          passphrase: null,
        ),
      );
      final receiver = HostTransferReceiver();

      expect(receiver.receive(stagesA.keyStage),
          HostTransferStep.waitingForPayload);
      expect(
        () => receiver.receive(stagesB.payloadStage),
        throwsA(isA<HostTransferMismatchError>()),
      );
    });

    test('a single stage alone never yields the host', () async {
      final stages = await createHostTransferStages(_host());
      final receiver = HostTransferReceiver();

      expect(receiver.receive(stages.keyStage),
          HostTransferStep.waitingForPayload);
      expect(
        () => receiver.complete(),
        throwsA(isA<HostTransferFormatError>()),
      );

      final onlyPayload = HostTransferReceiver();
      expect(onlyPayload.receive(stages.payloadStage),
          HostTransferStep.waitingForKey);
      expect(
        () => onlyPayload.complete(),
        throwsA(isA<HostTransferFormatError>()),
      );
    });

    test('rejects expired transfers', () async {
      final stages = await createHostTransferStages(
        _host(),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      final receiver = HostTransferReceiver();

      receiver.receive(stages.keyStage);
      receiver.receive(stages.payloadStage);

      await expectLater(receiver.complete(), throwsA(isA<HostTransferExpiredError>()));
    });

    test('rejects malformed payloads', () async {
      final receiver = HostTransferReceiver();
      expect(
        () => receiver.receive('not json'),
        throwsA(isA<HostTransferFormatError>()),
      );
    });
  });

  group('importHostFromTransfer', () {
    test('creates a host with an allocated local port and stores the key',
        () async {
      final repository = HostRepository(SharedPreferencesHostStore());
      final keyStore = PrivateKeyStore();
      final host = await importHostFromTransfer(
        _host(),
        repository: repository,
        keyStore: keyStore,
      );

      expect(host.localPort, 49375);
      expect(host.privateKeyRef, 'host.${host.id}.privateKey');
      expect((await keyStore.read(host.id))?.$1, contains('OPENSSH'));
      expect((await repository.all()).single.id, host.id);
    });

    test('matches an existing host and keeps its local port', () async {
      final repository = HostRepository(SharedPreferencesHostStore());
      final keyStore = PrivateKeyStore();
      final first = await importHostFromTransfer(
        _host(),
        repository: repository,
        keyStore: keyStore,
      );
      final kept = Host(
        id: first.id,
        name: first.name,
        type: first.type,
        host: first.host,
        port: first.port,
        username: first.username,
        privateKeyRef: first.privateKeyRef,
        hasPassphrase: first.hasPassphrase,
        remotePort: first.remotePort,
        localPort: 50001,
        autoStartServer: first.autoStartServer,
      );
      await repository.upsert(kept);

      final result = await importHostFromTransfer(
        const HostTransferData(
          name: 'renamed',
          address: '192.0.2.10',
          port: 22,
          username: 'duan',
          remotePort: 49374,
          autoStart: false,
          privateKey: '-----BEGIN OPENSSH PRIVATE KEY-----\nBBBB\n-----END OPENSSH PRIVATE KEY-----',
          passphrase: null,
        ),
        repository: repository,
        keyStore: keyStore,
      );

      expect(result.id, first.id);
      expect(result.localPort, 50001);
      expect(result.name, 'renamed');
      expect((await repository.all()).length, 1);
    });
  });
}
