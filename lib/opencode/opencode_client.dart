import 'dart:convert';

import '../core/app_language.dart';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import 'opencode_errors.dart';

String? parsePairUrl(String output) {
  final match =
      RegExp(r'https?://[^\s]+/auth/connect/[^\s]+').firstMatch(output);
  return match?.group(0);
}

enum ServerStatus { online, offline }

class PairingCode {
  const PairingCode(this.code, this.expiresIn);

  final String code;
  final int expiresIn;
}

class PairingSession {
  const PairingSession({
    required this.baseUrl,
    required this.cookieName,
    required this.cookieValue,
  });

  final String baseUrl;
  final String cookieName;
  final String cookieValue;
}

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
      final response = await request.close();
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

  Future<PairingCode> createPairingCode(
    String baseUrl, {
    String? password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/pair');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri);
      if (password != null && password.isNotEmpty) {
        final token = base64Encode(utf8.encode('opencode:$password'));
        request.headers.set(HttpHeaders.authorizationHeader, 'Basic $token');
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw PairingFailed(
          AppL10n.t.pairingFailedHttp(response.statusCode.toString()),
          cause: body,
        );
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return PairingCode(
        json['code'] as String,
        json['expires_in'] as int,
      );
    } on OpencodeError {
      rethrow;
    } catch (error) {
      throw PairingFailed(AppL10n.t.pairingFailed(error.toString()), cause: error);
    } finally {
      client.close(force: true);
    }
  }

  String pairUrl(String baseUrl, String code) => '$baseUrl/auth/connect/$code';

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
      final response = await request.close();
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

  Future<String?> sessionDirectory(
    String baseUrl,
    String sessionId, {
    String? cookieName,
    String? cookieValue,
  }) async {    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(
        Uri.parse('$baseUrl/api/session/$sessionId'),
      );
      if (cookieName != null && cookieValue != null) {
        request.headers.set(
          HttpHeaders.cookieHeader,
          '$cookieName=$cookieValue',
        );
      }
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final location = json['location'];
        if (location is Map<String, dynamic>) {
          final directory = location['directory'];
          if (directory is String && directory.isNotEmpty) {
            return directory;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> currentSessionDirectory(
    String baseUrl, {
    String? cookieName,
    String? cookieValue,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/session'));
      if (cookieName != null && cookieValue != null) {
        request.headers.set(
          HttpHeaders.cookieHeader,
          '$cookieName=$cookieValue',
        );
      }
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final data = json['data'];
        if (data is List) {
          for (final item in data) {
            if (item is Map<String, dynamic>) {
              final location = item['location'];
              if (location is Map<String, dynamic>) {
                final directory = location['directory'];
                if (directory is String && directory.isNotEmpty) {
                  return directory;
                }
              }
            }
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> currentLocationDirectory(
    String baseUrl, {
    String? cookieName,
    String? cookieValue,
  }) async {    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/location'));
      if (cookieName != null && cookieValue != null) {
        request.headers.set(
          HttpHeaders.cookieHeader,
          '$cookieName=$cookieValue',
        );
      }
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final directory = json['directory'];
        if (directory is String && directory.isNotEmpty) return directory;
        final project = json['project'];
        if (project is Map<String, dynamic>) {
          final projectDir = project['directory'];
          if (projectDir is String && projectDir.isNotEmpty) return projectDir;
        }
      }
      return null;
    } catch (_) {
      return null;
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
    final binary = await _findBinary(client);
    if (binary == null) {
      throw OpencodeNotInstalled(AppL10n.t.hostOpencodeMissing);
    }
    try {
      final output = utf8.decode(
        await client.run('$binary pair --url $localBaseUrl'),
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

  /// 生成一次性配对链接，并在 App 内兑换成会话 cookie。
  ///
  /// 这样 WebView 只需要加载 Web UI 根路径，避免一次性链接被重复消费。
  Future<PairingSession> createSession(
    SSHClient client, {
    required String localBaseUrl,
  }) async {
    final pairUrl = await pairViaSsh(client, localBaseUrl: localBaseUrl);
    return redeemPairUrl(pairUrl, baseUrl: localBaseUrl);
  }

  Future<PairingSession> redeemPairUrl(
    String pairUrl, {
    required String baseUrl,
  }) async {    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(pairUrl));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml',
      );
      final response = await request.close();
      await response.drain<void>();

      final cookies = response.headers['set-cookie'];
      if (cookies == null || cookies.isEmpty) {
        throw PairingFailed(
          AppL10n.t.pairingNoCookie(response.statusCode.toString()),
        );
      }
      final first = cookies.first.split(';').first;
      final index = first.indexOf('=');
      if (index <= 0) {
        throw PairingFailed(AppL10n.t.parseCookieFailed);
      }
      return PairingSession(
        baseUrl: baseUrl,
        cookieName: first.substring(0, index).trim(),
        cookieValue: first.substring(index + 1).trim(),
      );
    } on OpencodeError {
      rethrow;
    } catch (error) {
      throw PairingFailed(AppL10n.t.redeemFailed(error.toString()), cause: error);
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _findBinary(SSHClient client) async {
    // Non-interactive SSH does not load .bashrc/.zshrc, so `command -v`
    // misses PATH entries added by installers. Probe login shells first.
    for (final shell in ['bash', 'zsh', 'sh']) {
      try {
        final result = utf8.decode(
          await client.run(
            '$shell -lc "command -v opencode" 2>/dev/null',
          ),
        );
        for (final line in result.split('\n').reversed) {
          final value = line.trim();
          if (value.isNotEmpty && value.endsWith('opencode')) {
            return value;
          }
        }
      } catch (_) {}
    }

    const candidates = [
      'opencode',
      '~/.opencode/bin/opencode',
      '~/.local/bin/opencode',
      '~/.bun/bin/opencode',
      '/usr/local/bin/opencode',
      '/opt/homebrew/bin/opencode',
    ];
    for (final candidate in candidates) {
      final result = utf8.decode(
        await client.run(
          'if command -v $candidate >/dev/null 2>&1; then command -v $candidate; '
          'elif [ -x $candidate ]; then echo $candidate; fi',
        ),
      ).trim();
      if (result.isNotEmpty) {
        return result.split('\n').last.trim();
      }
    }
    return null;
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

  Future<bool> isInstalled(SSHClient client) async {
    return await _findBinary(client) != null;
  }

  Future<void> startService(SSHClient client) async {
    final binary = await _findBinary(client);
    if (binary == null) {
      throw OpencodeNotInstalled(AppL10n.t.hostOpencodeMissing);
    }
    try {
      await client.run('$binary service start');
      final status = utf8.decode(await client.run('$binary service status'));
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
