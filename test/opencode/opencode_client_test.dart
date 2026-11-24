import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/opencode/opencode_client.dart';

void main() {
  late HttpServer server;
  late OpencodeClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = OpencodeClient();
  });

  tearDown(() => server.close(force: true));

  test('probe treats 200 as online', () async {
    server.listen((req) {
      req.response.statusCode = 200;
      req.response.write('{"version":"2.2.5"}');
      req.response.close();
    });
    final status = await client.probe('http://127.0.0.1:${server.port}');
    expect(status, ServerStatus.online);
  });

  test('probe treats 401 as online', () async {
    server.listen((req) {
      req.response.statusCode = 401;
      req.response.close();
    });
    final status = await client.probe('http://127.0.0.1:${server.port}');
    expect(status, ServerStatus.online);
  });

  test('probe treats connection refused as offline', () async {
    final port = server.port;
    await server.close(force: true);
    final status = await client.probe('http://127.0.0.1:$port');
    expect(status, ServerStatus.offline);
  });

}
