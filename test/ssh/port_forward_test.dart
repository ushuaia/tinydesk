import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/ssh/port_forward.dart';
import 'package:tinydesk/ssh/ssh_errors.dart';

void main() {
  test('throws TunnelFailed when local port is occupied', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(blocker.close);

    await expectLater(
      PortForwarder().ensurePortAvailable(blocker.port),
      throwsA(isA<TunnelFailed>()),
    );
  });

  test('succeeds when port is free', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final freePort = socket.port;
    await socket.close();

    await expectLater(
      PortForwarder().ensurePortAvailable(freePort),
      completes,
    );
  });
}
