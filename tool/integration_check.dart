import 'dart:io';

import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/opencode/opencode_client.dart';
import 'package:tinydesk/ssh/port_forward.dart';
import 'package:tinydesk/ssh/ssh_connector.dart';

Future<void> main() async {
  final env = Platform.environment;
  final home = env['HOME'];
  final keyPath = env['OC_TEST_KEY'] ?? '$home/.ssh/id_ed25519';
  final key = File(keyPath).readAsStringSync();

  final host = Host(
    id: 'integration',
    name: 'integration',
    host: env['OC_TEST_HOST'] ?? '127.0.0.1',
    port: int.parse(env['OC_TEST_PORT'] ?? '22'),
    username: env['OC_TEST_USER'] ?? 'test',
    remotePort: int.parse(env['OC_TEST_REMOTE_PORT'] ?? '49374'),
    localPort: int.parse(env['OC_TEST_LOCAL_PORT'] ?? '49375'),
    autoStartServer: false,
  );

  stdout.writeln('1. SSH connecting to ${host.host}:${host.port}...');
  final client = await SshConnector().connect(
    host,
    privateKey: key,
    onUnknownHostKey: (fp) async {
      stdout.writeln('   host fingerprint: $fp');
      return true;
    },
    onHostKeyChanged: (_, _) async => true,
  );

  stdout.writeln('2. Opening local forward ${host.localPort} -> ${host.remotePort}...');
  final forward = await PortForwarder().start(
    client,
    localPort: host.localPort,
    remotePort: host.remotePort,
  );

  try {
    final opencode = OpencodeClient();
    final baseUrl = 'http://127.0.0.1:${host.localPort}';

    stdout.writeln('3. Probing opencode...');
    final status = await opencode.probe(baseUrl);
    if (status != ServerStatus.online) {
      stderr.writeln('FAIL: opencode is offline');
      exitCode = 1;
      return;
    }

    stdout.writeln('4. Creating one-time pairing link over SSH...');
    final pairUrl = await opencode.pairViaSsh(
      client,
      localBaseUrl: baseUrl,
    );
    stdout.writeln(
      '   link: ${pairUrl.replaceFirst(RegExp(r'/auth/connect/\S+'), '/auth/connect/<redacted>')}',
    );

    stdout.writeln('5. Redeeming the link (expects a session cookie)...');
    final http = HttpClient();
    final request = await http.getUrl(Uri.parse(pairUrl));
    request.followRedirects = false;
    final response = await request.close();
    await response.drain<void>();
    final redeemed = response.statusCode < 400;
    stdout.writeln('   status: ${response.statusCode}');
    stdout.writeln('   link redeemed: $redeemed');
    http.close(force: true);
  } finally {
    await forward.close();
    client.close();
  }
}
