import 'dart:convert';

import '../core/app_language.dart';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import 'opencode_cli.dart';
import 'opencode_errors.dart';

String? parsePairUrl(String output) {
  final match =
      RegExp(r'https?://[^\s]+/auth/connect/[^\s]+').firstMatch(output);
  return match?.group(0);
}

enum ServerStatus { online, offline }

class RemoteProject {
  const RemoteProject({required this.name, required this.directory});

  final String name;
  final String directory;
}

class OpencodeClient {
  Future<ServerStatus> probe(String baseUrl) async {
    final uri = Uri.parse('$baseUrl/api/info');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      return (response.statusCode == 200 || response.statusCode == 401)
          ? ServerStatus.online
          : ServerStatus.offline;
    } on SocketException {
      return ServerStatus.offline;
    } catch (_) {
      return ServerStatus.offline;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<RemoteProject>> listProjects(
    String baseUrl, {
    String? cookieName,
    String? cookieValue,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/project'));
      if (cookieName != null && cookieValue != null) {
        request.headers.set(
          HttpHeaders.cookieHeader,
          '$cookieName=$cookieValue',
        );
      }
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        await response.drain<void>();
        return const [];
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is! List) return const [];
      final projects = <RemoteProject>[];
      for (final item in json) {
        if (item is! Map<String, dynamic>) continue;
        final canonical = item['canonical'];
        if (canonical is! String || canonical.isEmpty) continue;
        final name = item['name'];
        projects.add(
          RemoteProject(
            name: name is String && name.isNotEmpty ? name : canonical,
            directory: canonical,
          ),
        );
      }
      return projects;
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  /// 通过 SSH 在主机本机执行 `opencode pair --url`，生成一次性配对链接。
  ///
  /// 这条路径不需要 App 持有 opencode 的服务密码：命令在主机本机运行，
  /// 链接直接指向手机侧的本地转发地址。
  Future<String> pairViaSsh(
    SSHClient client, {
    required String localBaseUrl,
  }) async {
    final cli = await _resolveCli(client);
    try {
      final output = utf8.decode(
        await client.run(cli.command('pair --url ${shellQuote(localBaseUrl)}')),
      );
      final url = parsePairUrl(output);
      if (url == null) {
        throw PairingFailed(AppL10n.t.parsePairFailed(output));
      }
      return url;
    } on OpencodeError {
      rethrow;
    } catch (error) {
      throw PairingFailed(AppL10n.t.createPairFailed(error.toString()), cause: error);
    }
  }

  /// Finds the host's opencode CLI with the same lookup the upgrade dialog
  /// uses, so an install that upgrade can see is also one that can start.
  Future<OpencodeCli> _resolveCli(SSHClient client) async {
    final cli = await resolveOpencodeCli(
      (command) async => utf8.decode(await client.run(command)),
    );
    if (cli == null) {
      throw OpencodeNotInstalled(AppL10n.t.hostOpencodeMissing);
    }
    return cli;
  }

  /// Looks for the opencode HTTP service on the remote host and reports the
  /// port it is serving on. Two passes:
  ///  1. Read the listening sockets of any opencode process via `ss`.
  ///  2. Probe a list of common ports with curl against /api/info
  ///     (a 200 or 401 response marks a live opencode server).
  Future<int?> detectServerPort(SSHClient client) async {
    try {
      final output = utf8.decode(await client.run(
        'ss -ltnp 2>/dev/null | grep -i opencode || true',
      ));
      for (final line in output.split('\n')) {
        final match = RegExp(r'(\d{4,5})').firstMatch(line);
        if (match != null) {
          final port = int.tryParse(match.group(1) ?? '');
          if (port != null && port > 1023) return port;
        }
      }
    } catch (_) {}

    for (final port in const [49374, 4096, 3000, 8080, 19001]) {
      final cmd = 'curl -s -o /dev/null -w "%{http_code}" -m 2 '
          'http://127.0.0.1:$port/api/info 2>/dev/null';
      try {
        final output = utf8.decode(await client.run(cmd));
        final code = output.trim().replaceAll(RegExp(r'\D'), '');
        if (code == '200' || code == '401') return port;
      } catch (_) {}
    }
    return null;
  }

  Future<void> startService(SSHClient client) async {
    final cli = await _resolveCli(client);
    try {
      await client.run(cli.command('service start'));
      final status =
          utf8.decode(await client.run(cli.command('service status')));
      if (!status.contains('http://')) {
        throw ServiceStartFailed(AppL10n.t.serviceStartFailedStatus(status));
      }
    } on OpencodeError {
      rethrow;
    } catch (error) {
      throw ServiceStartFailed(AppL10n.t.serviceStartFailed(error.toString()), cause: error);
    }
  }
}
