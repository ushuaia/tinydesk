import 'dart:convert';
import 'dart:math';

/// Rewrites local image references inside Markdown so the embedded reader
/// can serve them through the loopback asset server.
///
/// `![alt](img.png)` next to the document becomes
/// `/img?t=<token>&p=<base64 absolute path>`; remote `http(s)://` and
/// `data:` references are left untouched. The token is random per session,
/// and the asset server verifies it plus a base-directory prefix before
/// serving any bytes — the endpoint never becomes an arbitrary file read.
const allowedImageExtensions = {
  'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'ico',
};

final _markdownImagePattern = RegExp(r'(!\[[^\]]*\]\()([^)]+)(\))');
final _htmlImagePattern = RegExp(r'(<img[^>]+src=")([^"]+)(")', caseSensitive: false);
final _titleSuffixPattern = RegExp(r'^(.*?)\s+(".*")$');

/// Resolves a Markdown image reference against the document directory.
///
/// Returns the normalized POSIX path, or null for remote/data references.
String? resolveMarkdownImagePath(String baseDir, String reference) {
  var raw = reference.trim();
  if (raw.startsWith('<') && raw.endsWith('>')) {
    raw = raw.substring(1, raw.length - 1);
  }
  try {
    raw = Uri.decodeComponent(raw);
  } catch (_) {}
  if (raw.startsWith('http://') ||
      raw.startsWith('https://') ||
      raw.startsWith('data:')) {
    return null;
  }
  final combined = raw.startsWith('/')
      ? raw
      : (baseDir.endsWith('/') ? '$baseDir$raw' : '$baseDir/$raw');
  return _normalizePosixPath(combined);
}

/// True when [path] stays inside [baseDir] (or equals it).
bool isInsideDirectory(String path, String baseDir) {
  final normalized = _normalizePosixPath(path);
  final root = _normalizePosixPath(baseDir);
  if (normalized == root) return true;
  if (root == '/' || root.isEmpty) return true;
  return normalized.startsWith('$root/');
}

/// Rewrites both `![alt](path)` and `<img src="path">` forms.
///
/// Code fences are skipped on purpose: inside them the reference is source
/// text the user wrote, not something the renderer will display.
String rewriteMarkdownImages(
  String markdown, {
  required String baseDir,
  required String token,
}) {
  final out = <String>[];
  var inCode = false;
  for (final line in markdown.split('\n')) {
    if (line.trimLeft().startsWith('```')) {
      inCode = !inCode;
      out.add(line);
      continue;
    }
    if (inCode) {
      out.add(line);
      continue;
    }
    var result = line.replaceAllMapped(_markdownImagePattern, (m) {
      final rebuilt = _rewriteSource(m.group(2), token, baseDir);
      if (rebuilt == null) return m.group(0)!;
      return '${m.group(1)}${rebuilt.src}${rebuilt.suffix})';
    });
    result = result.replaceAllMapped(_htmlImagePattern, (m) {
      final rebuilt = _rewriteSource(m.group(2), token, baseDir);
      if (rebuilt == null) return m.group(0)!;
      return '${m.group(1)}${rebuilt.src}${rebuilt.suffix}${m.group(3)}';
    });
    out.add(result);
  }
  return out.join('\n');
}

({String src, String suffix})? _rewriteSource(
  String? rawSource,
  String token,
  String baseDir,
) {
  if (rawSource == null) return null;
  var reference = rawSource.trim();

  // Split an optional title suffix: ![alt](path "title")
  var suffix = '';
  final titleMatch = _titleSuffixPattern.firstMatch(reference);
  if (titleMatch != null) {
    reference = titleMatch.group(1)!;
    suffix = ' ${titleMatch.group(2)!}';
  }
  if (reference.startsWith('<') && reference.endsWith('>')) {
    reference = reference.substring(1, reference.length - 1);
  }

  final resolved = resolveMarkdownImagePath(baseDir, reference);
  if (resolved == null) return null;

  final encoded = base64Url.encode(utf8.encode(resolved));
  return (src: '/img?t=$token&p=$encoded', suffix: suffix);
}

String _normalizePosixPath(String path) {
  final absolute = path.startsWith('/');
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty) out.removeLast();
      continue;
    }
    out.add(part);
  }
  final joined = out.join('/');
  if (absolute) return '/$joined';
  return joined;
}

String randomImageToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(8, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String contentTypeForExtension(String path) {
  final extension = path.contains('.')
      ? path.substring(path.lastIndexOf('.') + 1).toLowerCase()
      : '';
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'svg':
      return 'image/svg+xml';
    case 'bmp':
      return 'image/bmp';
    case 'ico':
      return 'image/x-icon';
    default:
      return 'application/octet-stream';
  }
}
