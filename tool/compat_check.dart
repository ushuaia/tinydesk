#!/usr/bin/env dart
// Verifies the opencode integration contracts TinyDesk depends on.
//
// Usage:
//   dart run tool/compat_check.dart [http://127.0.0.1:49374]
//
// Expects a running `opencode serve` on the given base URL. Exits non-zero
// when any contract changed, so CI can flag upstream protocol breaks before
// users hit them.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final base = args.isNotEmpty ? args.first : 'http://127.0.0.1:49374';
  final checks = <String, Future<bool> Function()>{
    'CLI version': () => _checkCliVersion(),
    'CLI pairing link': () => _checkPairCli(base),
    'WebView login page': () => _checkWebViewLogin(base),
    'API token redemption': () => _checkTokenRedemption(base),
    'Session list API': () => _checkSessionList(base),
    'Web UI locale store': () => _checkLocaleStore(base),
  };

  var failures = 0;
  for (final entry in checks.entries) {
    bool ok;
    try {
      ok = await entry.value();
    } catch (error) {
      stdout.writeln('FAIL ${entry.key}: $error');
      failures++;
      continue;
    }
    stdout.writeln('${ok ? 'ok  ' : 'FAIL'} ${entry.key}');
    if (!ok) failures++;
  }

  stdout.writeln(failures == 0
      ? 'compat: all contracts hold'
      : 'compat: $failures contract(s) changed');
  exit(failures == 0 ? 0 : 1);
}

Future<bool> _checkCliVersion() async {
  final result = await Process.run('opencode', ['--version']);
  if (result.exitCode != 0) return false;
  final version = (result.stdout as String).trim();
  stdout.writeln('     version: $version');
  return RegExp(r'v?\d+\.\d+').hasMatch(version);
}

Future<bool> _checkPairCli(String base) async {
  final result = await Process.run('opencode', ['pair', '--url', base]);
  if (result.exitCode != 0) {
    stdout.writeln('     pair exit=${result.exitCode} '
        'err=${result.stderr.toString().trim()}');
    return false;
  }
  final hasUrl = _pairUrl(result.stdout as String) != null;
  if (!hasUrl) {
    stdout.writeln('     pair stdout had no link: '
        '"${(result.stdout as String).trim().substring(0, result.stdout.toString().trim().length.clamp(0, 200))}"');
  }
  return hasUrl;
}

Future<bool> _checkWebViewLogin(String base) async {
  final url = await _freshPairUrl(base);
  if (url == null) return false;
  // A browser (and the app's WebView) follows the redirect chain; the login
  // happens along it. Accept either a redirect or an HTML/token body.
  var current = url;
  for (var hop = 0; hop < 4; hop++) {
    final response = await _get(
      current,
      headers: {
        HttpHeaders.acceptHeader: 'text/html,application/xhtml+xml',
        HttpHeaders.userAgentHeader:
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
      },
    );
    if (response == null) {
      stdout.writeln('     login-hop: no response from $current');
      return false;
    }
    if (response.statusCode == 302 || response.statusCode == 303) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      stdout.writeln('     redirect: ${response.statusCode} → $location');
      if (location == null) return false;
      current = Uri.parse(current).resolve(location).toString();
      continue;
    }
    final isHtml = response.headers.contentType?.mimeType == 'text/html';
    final hasToken = _token(response.body) != null;
    return response.statusCode == 200 && (isHtml || hasToken);
  }
  return false;
}

Future<bool> _checkTokenRedemption(String base) async {
  final url = await _freshPairUrl(base);
  if (url == null) {
    stdout.writeln('     token-check: no pair link to redeem');
    return false;
  }
  final response = await _get(
    url,
    headers: {HttpHeaders.acceptHeader: 'application/json'},
  );
  if (response == null) {
    stdout.writeln('     token-check: redeem request failed');
    return false;
  }
  final token = _token(response.body);
  if (token == null) {
    stdout.writeln('     token-check: body=${response.body.trim().substring(0, response.body.trim().length.clamp(0, 200))}');
    return false;
  }
  final port = Uri.parse(base).port;
  final session = await _get(
    '$base/api/session',
    headers: {HttpHeaders.cookieHeader: 'opencode_session_$port=$token'},
  );
  return session?.statusCode == 200;
}

Future<bool> _checkSessionList(String base) async {
  // /api/session without auth must exist and answer (401 is expected and
  // proves the endpoint still lives at this path).
  final response = await _get('$base/api/session');
  if (response == null) return false;
  stdout.writeln('     status: ${response.statusCode}');
  return response.statusCode == 200 || response.statusCode == 401;
}

Future<bool> _checkLocaleStore(String base) async {
  final index = await _get('$base/');
  if (index == null) return false;
  final match =
      RegExp(r'src="([^"]*_assets/index-[^"]+\.js)"').firstMatch(index.body);
  if (match == null) return false;
  final js = await _get('$base${match.group(1)}');
  if (js == null) return false;
  // The language store key lives in the lazily loaded language chunk; its
  // name is referenced from the main bundle.
  final chunk = RegExp(r'_assets/language-[A-Za-z0-9_-]+\.js').firstMatch(js.body);
  if (chunk == null) return false;
  final language = await _get('$base/${chunk.group(0)}');
  if (language == null) return false;
  // The web UI reads its language from this localStorage key; the language
  // sync feature writes it.
  return language.body.contains('opencode.global.dat:language');
}

Future<String?> _freshPairUrl(String base) async {
  final result = await Process.run('opencode', ['pair', '--url', base]);
  if (result.exitCode != 0) {
    stdout.writeln('     fresh-pair exit=${result.exitCode} '
        'err=${result.stderr.toString().trim()}');
    return null;
  }
  final url = _pairUrl(result.stdout as String);
  if (url == null) {
    stdout.writeln('     fresh-pair stdout had no link');
  }
  return url;
}

String? _pairUrl(String output) {
  final match = RegExp(r'https?://[^\s]+/auth/connect/[A-Za-z0-9_-]+')
      .firstMatch(output);
  return match?.group(0);
}

String? _token(String body) {
  final trimmed = body.trim();
  if (!trimmed.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map && decoded['token'] is String) {
      return decoded['token'] as String;
    }
  } on FormatException {
    return null;
  }
  return null;
}

Future<_Response?> _get(
  String url, {
  Map<String, String>? headers,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.followRedirects = false;
    headers?.forEach(request.headers.set);
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return _Response(response.statusCode, response.headers, body);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

class _Response {
  _Response(this.statusCode, this.headers, this.body);

  final int statusCode;
  final HttpHeaders headers;
  final String body;
}
