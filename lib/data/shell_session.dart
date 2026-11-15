import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_pty/flutter_pty.dart';

/// Transport-agnostic interactive shell used by the terminal UI.
///
/// The remote (SSH) and local (PTY) implementations expose the same surface,
/// so `TerminalController` and xterm stay identical for both.
abstract class ShellSession {
  Stream<Uint8List> get stdout;

  StreamSink<Uint8List> get stdin;

  void resizeTerminal(
    int width,
    int height, [
    int pixelWidth = 0,
    int pixelHeight = 0,
  ]);

  Future<void> get done;

  void close();
}

/// Wraps a dartssh2 [SSHSession].
class SshShellSession implements ShellSession {
  SshShellSession(this._session);

  final SSHSession _session;

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  StreamSink<Uint8List> get stdin => _session.stdin;

  @override
  void resizeTerminal(
    int width,
    int height, [
    int pixelWidth = 0,
    int pixelHeight = 0,
  ]) {
    _session.resizeTerminal(width, height, pixelWidth, pixelHeight);
  }

  @override
  Future<void> get done => _session.done;

  @override
  void close() {
    try {
      _session.close();
    } catch (_) {}
  }
}

/// Wraps a local pseudo-terminal from flutter_pty.
class LocalShellSession implements ShellSession {
  LocalShellSession(this._pty) {
    _done = _pty.exitCode.then((_) {}).catchError((Object _) {});
  }

  final Pty _pty;
  late final Future<void> _done;
  late final StreamSink<Uint8List> _stdin = _PtySink(_pty);

  @override
  Stream<Uint8List> get stdout => _pty.output;

  @override
  StreamSink<Uint8List> get stdin => _stdin;

  @override
  void resizeTerminal(
    int width,
    int height, [
    int pixelWidth = 0,
    int pixelHeight = 0,
  ]) {
    try {
      _pty.resize(height, width);
    } catch (_) {}
  }

  @override
  Future<void> get done => _done;

  @override
  void close() {
    try {
      _pty.kill();
    } catch (_) {}
  }
}

class _PtySink implements StreamSink<Uint8List> {
  _PtySink(this._pty);

  final Pty _pty;

  @override
  void add(Uint8List event) {
    _pty.write(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Uint8List> stream) async {
    await for (final chunk in stream) {
      _pty.write(chunk);
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future<void>.value();
}
