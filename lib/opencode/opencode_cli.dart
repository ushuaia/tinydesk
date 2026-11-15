import 'dart:convert';

/// Runs a shell command on the target host and returns its combined output.
typedef CommandRunner = Future<String> Function(String command);

/// Resolved opencode CLI on the host.
///
/// SSH `exec` requests run without a login shell, so the PATH usually misses
/// the directory the installer appended to `.bashrc`/`.zshrc`. When a login
/// shell found the binary we keep using that shell, because npm-installed
/// builds are `#!/usr/bin/env node` shims that need the same PATH to find
/// `node`.
class OpencodeCli {
  const OpencodeCli({required this.executable, this.loginShell});

  final String executable;
  final String? loginShell;

  /// Builds a shell command that runs [executable] with [arguments].
  String command(String arguments) {
    final direct = '${shellQuote(executable)} $arguments';
    final shell = loginShell;
    if (shell == null) return direct;
    return '$shell -lc ${shellQuote(direct)}';
  }
}

/// Quotes [value] for POSIX shells.
String shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

/// Extracts a version such as `2.3.0` from CLI output.
///
/// Login shells may print banners before the actual output, so lines that
/// mention `opencode` win; only when no such line exists does the last
/// version-looking token count. Returns null when nothing parses, so shell
/// errors such as `opencode: command not found` never reach the UI as a
/// version.
String? parseOpencodeVersion(String raw) {
  for (final line in const LineSplitter().convert(raw).reversed) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (!trimmed.toLowerCase().contains('opencode')) continue;
    final match = _versionPattern.firstMatch(trimmed);
    if (match != null) return match.group(1);
  }

  final matches = _versionPattern.allMatches(raw);
  if (matches.isEmpty) return null;
  return matches.last.group(1);
}

final _versionPattern = RegExp(r'(\d+\.\d+\.\d+(?:[-+][\w.\-]+)?)');

const _loginShells = ['bash', 'zsh', 'sh'];

const _candidateScript = r'''
for p in "$HOME/.opencode/bin/opencode" "$HOME/.npm-global/bin/opencode" "$HOME/.local/bin/opencode" "$HOME/.bun/bin/opencode" "$HOME/.volta/bin/opencode" "$HOME"/.nvm/versions/node/*/bin/opencode "/usr/local/bin/opencode" "/opt/homebrew/bin/opencode"; do
  if [ -x "$p" ]; then echo "$p"; break; fi
done
exit 0
''';

/// Locates the opencode executable on the host.
///
/// Login shells are probed first (they load the installer's PATH), then the
/// well-known install directories. Returns null when opencode is missing.
Future<OpencodeCli?> resolveOpencodeCli(CommandRunner run) async {
  for (final shell in _loginShells) {
    final output = await _tryRun(
      run,
      "$shell -lc 'command -v opencode' 2>/dev/null; exit 0",
    );
    final path = _lastExecutableLine(output);
    if (path != null) {
      return OpencodeCli(executable: path, loginShell: shell);
    }
  }

  final output = await _tryRun(run, _candidateScript);
  final path = _lastExecutableLine(output);
  if (path != null) return OpencodeCli(executable: path);

  return null;
}

Future<String> _tryRun(CommandRunner run, String command) async {
  try {
    return await run(command);
  } catch (_) {
    return '';
  }
}

String? _lastExecutableLine(String output) {
  for (final line in const LineSplitter().convert(output).reversed) {
    final value = line.trim();
    if (value.isEmpty) continue;
    if (value.endsWith('/opencode') || value == 'opencode') return value;
  }
  return null;
}
