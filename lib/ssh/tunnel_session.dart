import 'dart:convert';
import '../core/app_language.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../data/host.dart';
import '../data/remote_file.dart';
import '../opencode/opencode_client.dart';
import '../data/shell_session.dart';
import '../opencode/opencode_errors.dart';
import 'port_forward.dart';
import 'ssh_connector.dart';

/// A shell command on the host exited with a non-zero status.
class TunnelCommandException implements Exception {
  const TunnelCommandException(
    this.command, {
    required this.exitCode,
    this.stderr = '',
  });

  final String command;
  final int exitCode;
  final String stderr;

  @override
  String toString() {
    final detail = stderr.trim();
    if (detail.isEmpty) return AppL10n.t.commandFailedCode(exitCode.toString(), command);
    return detail;
  }
}

abstract class TunnelSession {
  Future<ServerStatus> probe(String baseUrl);

  Future<PairingSession> pairSession(String localBaseUrl);

  Future<void> startService();

  Future<List<RemoteFile>> listDirectory(String path);

  Future<String> readText(String path);

  Future<Uint8List> readBytes(String path);

  Future<void> writeText(String path, String content);

  /// Deletes a file or directory (directories are removed recursively).
  Future<void> delete(String path);

  /// Runs a shell command on the host and returns its stdout.
  /// Throws [TunnelCommandException] when the command exits non-zero.
  Future<String> runCommand(String command);

  Future<void> createDirectory(String path);

  Future<void> downloadFile(String remotePath, File destination);

  Future<String> homeDirectory();

  /// Returns the file's last-modified time, or null when the file does not
  /// exist or the platform cannot report it.
  Future<DateTime?> statModified(String path);

  Future<ShellSession> openShell({int width = 80, int height = 24});

  /// 底层 SSH 连接结束时完成。
  Future<void> get closed;

  /// 发送一次轻量命令，用于检测连接是否还活着。
  Future<void> keepAlive();

  Future<void> close();
}

typedef TunnelOpener = Future<TunnelSession> Function(
  Host host,
  String privateKey,
  String? passphrase,
  UnknownHostKeyHandler onUnknownHostKey,
  HostKeyChangedHandler onHostKeyChanged,
);

class SshTunnelSession implements TunnelSession {
  SshTunnelSession(this._client, this._forward, this._opencode);

  final SSHClient _client;
  final LocalForward _forward;
  final OpencodeClient _opencode;
  SftpClient? _sftp;

  Future<SftpClient> get _sftpClient async =>
      _sftp ??= await _client.sftp();

  @override
  Future<ServerStatus> probe(String baseUrl) => _opencode.probe(baseUrl);

  @override
  Future<PairingSession> pairSession(String localBaseUrl) =>
      _opencode.createSession(_client, localBaseUrl: localBaseUrl);

  @override
  Future<void> startService() => _opencode.startService(_client);

  @override
  Future<List<RemoteFile>> listDirectory(String path) async {
    final sftp = await _sftpClient;
    final resolved = path == '~' ? await homeDirectory() : path;
    final names = await sftp.listdir(resolved);
    final files = names
        .where((name) =>
            name.filename != '.' &&
            name.filename != '..' &&
            !name.filename.startsWith('.'))
        .map((name) {
      final modifyTime = name.attr.modifyTime;
      return RemoteFile(
        name: name.filename,
        path: _joinPath(resolved, name.filename),
        isDirectory: name.attr.isDirectory,
        size: name.attr.size,
        modifiedAt: modifyTime == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(modifyTime * 1000),
      );
    }).toList();
    files.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return files;
  }

  @override
  Future<DateTime?> statModified(String path) async {
    try {
      final sftp = await _sftpClient;
      final attrs = await sftp.stat(path);
      final mtime = attrs.modifyTime;
      if (mtime == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(mtime * 1000);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> homeDirectory() async {
    final result = await _client.run(r'printf %s "$HOME"');
    return utf8.decode(result).trim();
  }

  @override
  Future<ShellSession> openShell({int width = 80, int height = 24}) async {
    final shell = await _client.shell(
      pty: SSHPtyConfig(width: width, height: height),
    );
    return SshShellSession(shell);
  }

  String _joinPath(String dir, String name) =>
      dir.endsWith('/') ? '$dir$name' : '$dir/$name';

  @override
  Future<String> readText(String path) async =>
      utf8.decode(await readBytes(path));

  @override
  Future<Uint8List> readBytes(String path) async {
    final sftp = await _sftpClient;
    final file = await sftp.open(path);
    try {
      return await file.readBytes();
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> writeText(String path, String content) async {
    final sftp = await _sftpClient;
    final file = await sftp.open(
      path,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      await file.writeBytes(utf8.encode(content));
    } finally {
      await file.close();
    }
  }

  @override
  Future<String> runCommand(String command) async {
    final result = await _client.runWithResult(command);
    final exitCode = result.exitCode;
    if (exitCode != null && exitCode != 0) {
      throw TunnelCommandException(
        command,
        exitCode: exitCode,
        stderr: utf8.decode(result.stderr),
      );
    }
    return utf8.decode(result.stdout);
  }

  @override
  Future<void> delete(String path) async {
    final sftp = await _sftpClient;
    try {
      await sftp.remove(path);
      return;
    } catch (_) {}
    try {
      await sftp.rmdir(path);
      return;
    } catch (_) {}
    // Directory with content: remove the children first, then the folder.
    final children = await listDirectory(path);
    for (final child in children) {
      final char = child.path.endsWith('/') ? '' : '/';
      await delete('${child.path}$char');
    }
    await sftp.rmdir(path);
  }

  @override
  Future<void> createDirectory(String path) async {
    final sftp = await _sftpClient;
    try {
      await sftp.stat(path);
    } catch (_) {
      await sftp.mkdir(path);
    }
  }

  @override
  Future<void> downloadFile(String remotePath, File destination) async {
    final sftp = await _sftpClient;
    final sink = destination.openWrite();
    try {
      await sftp.download(
        remotePath,
        sink,
        closeDestination: true,
      );
    } catch (error) {
      try {
        await sink.close();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> get closed => _client.done;

  @override
  Future<void> keepAlive() async {
    await _client.run('true');
  }

  @override
  Future<void> close() async {
    await _sftp?.close();
    _sftp = null;
    await _forward.close();
    _client.close();
  }
}

Future<TunnelSession> openSshTunnel(
  Host host,
  String privateKey,
  String? passphrase,
  UnknownHostKeyHandler onUnknownHostKey,
  HostKeyChangedHandler onHostKeyChanged,
) async {
  final client = await SshConnector().connect(
    host,
    privateKey: privateKey,
    passphrase: passphrase,
    onUnknownHostKey: onUnknownHostKey,
    onHostKeyChanged: onHostKeyChanged,
  );

  final opencode = OpencodeClient();
  try {
    // Discover the port the opencode HTTP service is listening on.
    var remotePort = await opencode.detectServerPort(client);
    if (remotePort == null) {
      // Not serving yet: try starting it, then discover again.
      await opencode.startService(client);
      remotePort = await opencode.detectServerPort(client);
    }
    if (remotePort == null) {
      throw ServerUnreachable(AppL10n.t.remoteOpencodeUnreachable);
    }

    final forward = await PortForwarder().start(
      client,
      localPort: host.localPort,
      remotePort: remotePort,
    );
    return SshTunnelSession(client, forward, opencode);
  } catch (error) {
    client.close();
    rethrow;
  }
}
