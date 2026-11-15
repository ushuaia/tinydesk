import 'dart:convert';
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

  test('createPairingCode parses code and expiry', () async {
    server.listen((req) {
      expect(req.uri.path, '/api/pair');
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'code': 'abc', 'expires_in': 900}));
      req.response.close();
    });
    final code = await client.createPairingCode(
      'http://127.0.0.1:${server.port}',
    );
    expect(code.code, 'abc');
    expect(code.expiresIn, 900);
  });

  test('pairUrl builds auth connect link', () {
    expect(
      client.pairUrl('http://127.0.0.1:49375', 'abc'),
      'http://127.0.0.1:49375/auth/connect/abc',
    );
  });
}
