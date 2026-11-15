import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/opencode/opencode_cli.dart';

void main() {
  group('parseOpencodeVersion', () {
    test('reads a bare version', () {
      expect(parseOpencodeVersion('2.3.0\n'), '2.3.0');
    });

    test('reads a prefixed version', () {
      expect(parseOpencodeVersion('opencode 2.3.0'), '2.3.0');
    });

    test('ignores shell error text', () {
      // Reproduced in the wild: SSH exec has no PATH entry for opencode, so
      // stderr leaks into stdout and used to be displayed as the version.
      expect(
        parseOpencodeVersion('bash: line 1: opencode: command not found\n'),
        isNull,
      );
    });

    test('prefers the line that mentions opencode', () {
      expect(
        parseOpencodeVersion('Ubuntu 22.04.3 LTS\nopencode 2.3.0\n'),
        '2.3.0',
      );
    });

    test('skips banner noise after the version line', () {
      expect(
        parseOpencodeVersion('opencode 2.3.0\nWelcome to 24.04.1\n'),
        '2.3.0',
      );
    });

    test('returns null for empty output', () {
      expect(parseOpencodeVersion('  \n'), isNull);
    });
  });

  group('shellQuote', () {
    test('wraps plain text in single quotes', () {
      expect(shellQuote('/usr/local/bin/opencode'), "'/usr/local/bin/opencode'");
    });

    test('escapes embedded single quotes', () {
      expect(shellQuote("/tmp/it's here"), r"'/tmp/it'\''s here'");
    });
  });

  group('OpencodeCli.command', () {
    test('runs through the login shell that resolved the binary', () {
      const cli = OpencodeCli(executable: '/usr/local/bin/opencode');
      expect(
        cli.command('--version'),
        "'/usr/local/bin/opencode' --version",
      );
    });

    test('uses the login shell when one resolved the binary', () {
      const cli = OpencodeCli(
        executable: '/usr/local/bin/opencode',
        loginShell: 'bash',
      );
      expect(
        cli.command('--version'),
        r"""bash -lc ''\''/usr/local/bin/opencode'\'' --version'""",
      );
    });
  });

  group('resolveOpencodeCli', () {
    test('prefers the login shell result', () async {
      final commands = <String>[];
      final cli = await resolveOpencodeCli((command) async {
        commands.add(command);
        if (commands.length == 1) return '/home/u/.opencode/bin/opencode\n';
        return '';
      });

      expect(cli, isNotNull);
      expect(cli!.executable, '/home/u/.opencode/bin/opencode');
      expect(cli.loginShell, 'bash');
      expect(commands.first, contains('bash -lc'));
    });

    test('falls back to well-known install paths', () async {
      final cli = await resolveOpencodeCli((command) async {
        if (command.contains('bash -lc') || command.contains('zsh -lc')) {
          return '';
        }
        if (command.contains('sh -lc')) return '';
        if (command.contains('.opencode/bin/opencode')) {
          return '/home/u/.opencode/bin/opencode\n';
        }
        return '';
      });

      expect(cli, isNotNull);
      expect(cli!.executable, '/home/u/.opencode/bin/opencode');
      expect(cli.loginShell, isNull);
    });

    test('returns null when nothing is installed', () async {
      final cli = await resolveOpencodeCli((command) async => '');
      expect(cli, isNull);
    });

    test('skips noise printed by shell rc files', () async {
      final cli = await resolveOpencodeCli((command) async {
        if (command.contains('bash -lc')) {
          return 'welcome to the server\n/usr/bin/opencode\n';
        }
        return '';
      });

      expect(cli!.executable, '/usr/bin/opencode');
    });
  });
}
