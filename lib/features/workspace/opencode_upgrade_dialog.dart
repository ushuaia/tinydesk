import 'dart:convert';

import 'package:flutter/material.dart';

import '../../opencode/opencode_cli.dart';
import '../../ssh/tunnel_session.dart';

enum _Phase { loading, ready, upgrading, done, error }

/// Shows the host's current + latest opencode version and upgrades it.
class OpencodeUpgradeDialog extends StatefulWidget {
  const OpencodeUpgradeDialog({super.key, required this.session});

  final TunnelSession session;

  @override
  State<OpencodeUpgradeDialog> createState() => _OpencodeUpgradeDialogState();
}

class _OpencodeUpgradeDialogState extends State<OpencodeUpgradeDialog> {
  _Phase _phase = _Phase.loading;
  OpencodeCli? _cli;
  String? _current;
  String? _latest;
  String? _doneVersion;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  String? _parseRegistryVersion(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final version = json['version'];
        if (version is String && version.isNotEmpty) return version;
      }
    } catch (_) {}
    final match = RegExp(r'"version"\s*:\s*"([^"]+)"').firstMatch(body);
    return match?.group(1);
  }

  int _compareVersions(String a, String b) {
    int part(String value, int index) {
      final parts = value.split('.');
      if (index >= parts.length) return 0;
      final digits = RegExp(r'^\d+').firstMatch(parts[index])?.group(0);
      return int.tryParse(digits ?? '') ?? 0;
    }

    for (var i = 0; i < 3; i++) {
      final diff = part(a, i) - part(b, i);
      if (diff != 0) return diff;
    }
    return 0;
  }

  bool get _upToDate {
    final current = _current;
    final latest = _latest;
    if (current == null || latest == null) return false;
    return _compareVersions(current, latest) >= 0;
  }

  Future<void> _check() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      // SSH exec has no login shell, so resolve the binary through one first.
      final cli = await resolveOpencodeCli(widget.session.runCommand);
      if (cli == null) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.error;
          _cli = null;
          _current = null;
          _error = '未检测到 opencode。已尝试登录 shell 的 PATH 与常见安装目录。';
        });
        return;
      }
      _cli = cli;

      final currentRaw = await widget.session.runCommand(
        cli.command('--version'),
      );
      final current = parseOpencodeVersion(currentRaw);
      if (current == null) {
        throw const FormatException('无法解析 opencode 版本输出');
      }

      String? latest;
      try {
        final registry = await widget.session.runCommand(
          'curl -fsSL "https://registry.npmjs.org/@opencode%2Fcli/latest"',
        );
        latest = _parseRegistryVersion(registry);
      } catch (_) {}
      if (latest == null) {
        try {
          final npm = await widget.session
              .runCommand('npm view @opencode/cli version');
          latest = parseOpencodeVersion(npm);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _current = current;
        _latest = latest;
        _phase = _Phase.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = '无法读取 opencode 版本：${_describe(error)}';
      });
    }
  }

  Future<void> _upgrade() async {
    final cli = _cli;
    if (cli == null) {
      await _check();
      return;
    }
    setState(() {
      _phase = _Phase.upgrading;
      _error = null;
    });
    try {
      await widget.session.runCommand(cli.command('upgrade'));
      // Best effort: restart the service so the new binary takes effect.
      try {
        await widget.session.startService();
      } catch (_) {}
      String? version;
      try {
        // An upgrade may move the binary, so resolve it again.
        final refreshed =
            await resolveOpencodeCli(widget.session.runCommand) ?? cli;
        _cli = refreshed;
        final raw = await widget.session.runCommand(
          refreshed.command('--version'),
        );
        version = parseOpencodeVersion(raw);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _doneVersion = version;
        if (version != null) _current = version;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = '升级失败：${_describe(error)}';
      });
    }
  }

  /// Turns a raw command failure into a single readable line.
  String _describe(Object error) {
    if (error is TunnelCommandException) {
      final detail = error.stderr
          .split('\n')
          .map((line) => line
              .replaceFirst(RegExp(r'^(?:bash|zsh|sh): (?:line \d+: )?'), '')
              .trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => '');
      if (detail.isNotEmpty) return detail;
      return '命令执行失败（退出码 ${error.exitCode}）';
    }
    return error.toString();
  }

  Widget _versionRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value ?? '—',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('opencode 版本'),
      content: switch (_phase) {
        _Phase.loading => const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Text('正在获取版本信息…'),
            ],
          ),
        _Phase.upgrading => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _versionRow('当前版本', _current),
              _versionRow('最新版本', _latest),
              const SizedBox(height: 12),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('正在升级…'),
                ],
              ),
            ],
          ),
        _Phase.done => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _versionRow('当前版本', _doneVersion ?? _current),
              const SizedBox(height: 10),
              Text(
                '升级完成。如果 opencode 服务正在运行，已尝试自动重启服务。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        _Phase.error => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_current != null) _versionRow('当前版本', _current),
              if (_latest != null) _versionRow('最新版本', _latest),
              if (_current != null || _latest != null)
                const SizedBox(height: 10),
              Text(
                _error ?? '操作失败',
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ],
          ),
        _Phase.ready => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _versionRow('当前版本', _current),
              _versionRow('最新版本', _latest),
              if (_latest == null) ...[
                const SizedBox(height: 8),
                Text(
                  '无法获取最新版本（主机无法访问 npm registry）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ] else if (_upToDate) ...[
                const SizedBox(height: 8),
                Text(
                  '已是最新版本',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
      },
      actions: switch (_phase) {
        _Phase.upgrading => const [],
        _Phase.done => [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        _Phase.error => [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: _check,
              child: const Text('重试'),
            ),
          ],
        _Phase.loading => [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        _Phase.ready => [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: _upToDate ? null : _upgrade,
              child: const Text('升级'),
            ),
          ],
      },
    );
  }
}
