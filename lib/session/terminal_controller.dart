import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import '../core/app_language.dart';
import 'package:xterm/xterm.dart';

import '../data/shell_session.dart';
import '../ssh/tunnel_session.dart';
import '../data/app_settings.dart';

enum TerminalStatus { idle, opening, open, closed, error }

/// Owns the long-lived terminal buffer and its SSH shell.
///
/// The shell survives page navigation; minimizing only hides the UI.
class TerminalController extends ChangeNotifier {
  TerminalController({required this.sessionProvider}) {
    _attachTerminal();
    _loadFontSize();
  }

  final TunnelSession? Function() sessionProvider;

  // 3 万行滚动缓冲；xterm 会为每行分配单元格，过大会明显增加内存。
  Terminal terminal = Terminal(maxLines: 30000);
  final FocusNode focusNode = FocusNode(debugLabel: 'ssh terminal');

  TerminalStatus status = TerminalStatus.idle;
  String? error;

  /// Whether the floating UI is shown (ball or window).
  bool visible = false;

  /// Whether the floating window is expanded. False means the ball.
  bool expanded = false;

  bool ctrl = false;
  bool alt = false;

  /// Terminal font size, persisted through [AppSettings].
  int fontSize = AppSettings.terminalFontSizeDefault;

  ShellSession? _shell;
  StreamSubscription<String>? _stdout;
  bool _opening = false;
  bool _wasOpen = false;
  bool _disposed = false;

  bool get isOpen => status == TerminalStatus.open;
  bool get hasTerminal => visible || status != TerminalStatus.idle;

  Future<void> _loadFontSize() async {
    final size = await AppSettings().terminalFontSize();
    if (_disposed || size == fontSize) return;
    fontSize = size;
    _notify();
  }

  Future<void> setFontSize(int size) async {
    final clamped = size.clamp(
      AppSettings.terminalFontSizeMin,
      AppSettings.terminalFontSizeMax,
    );
    if (clamped == fontSize) return;
    fontSize = clamped;
    _notify();
    await AppSettings().setTerminalFontSize(clamped);
  }

  Future<void> adjustFontSize(int delta) => setFontSize(fontSize + delta);

  /// Sends literal text (paste) to the shell.
  void sendText(String text) {
    if (text.isEmpty) return;
    _send(text);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> show() async {
    if (_disposed) return;
    visible = true;
    expanded = true;
    _notify();
    if (status == TerminalStatus.idle ||
        status == TerminalStatus.closed ||
        status == TerminalStatus.error) {
      await open();
    }
  }

  Future<void> open() async {
    if (_disposed || _opening) return;
    final session = sessionProvider();
    if (session == null) {
      status = TerminalStatus.error;
      error = AppL10n.t.connectionNotReady;
      _notify();
      return;
    }

    _opening = true;
    status = TerminalStatus.opening;
    error = null;
    _notify();

    try {
      final shell = await session.openShell(
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      );
      if (_disposed) {
        shell.close();
        return;
      }
      if (!visible) {
        status = TerminalStatus.idle;
        shell.close();
        return;
      }

      _shell = shell;
      _wasOpen = true;
      shell.resizeTerminal(terminal.viewWidth, terminal.viewHeight);
      _stdout = utf8.decoder.bind(shell.stdout).listen(
        terminal.write,
        onError: (Object e) {
          if (_disposed) return;
          status = TerminalStatus.error;
          error = AppL10n.t.terminalErrorDetail(e.toString());
          _notify();
        },
      );
      unawaited(shell.done.then((_) {
        if (_disposed || _shell != shell) return;
        _shell = null;
        _stdout?.cancel();
        _stdout = null;
        status = TerminalStatus.closed;
        terminal.write(AppL10n.t.connectionClosedBanner);
        _notify();
      }));

      status = TerminalStatus.open;
      _notify();
      _resizeSoon();
    } catch (e) {
      status = TerminalStatus.error;
      error = AppL10n.t.openTerminalFailed(e.toString());
      _notify();
    } finally {
      _opening = false;
    }
  }

  void minimize() {
    if (_disposed) return;
    expanded = false;
    _notify();
  }

  Future<void> close() async {
    if (_disposed) return;
    visible = false;
    expanded = false;
    _wasOpen = false;
    final sub = _stdout;
    _stdout = null;
    await sub?.cancel();
    final shell = _shell;
    _shell = null;
    try {
      shell?.close();
    } catch (_) {}
    status = TerminalStatus.idle;
    error = null;
    ctrl = false;
    alt = false;
    terminal = Terminal(maxLines: 30000);
    _attachTerminal();
    _notify();
  }

  /// Called by [AppSessionManager] when the SSH connection is ready again.
  void onConnectionReady() {
    if (_disposed || !_wasOpen) return;
    if (status == TerminalStatus.open || status == TerminalStatus.opening) return;
    terminal.write(AppL10n.t.connectionResumedBanner);
    unawaited(open());
  }

  void toggleCtrl() {
    ctrl = !ctrl;
    _notify();
  }

  void toggleAlt() {
    alt = !alt;
    _notify();
  }

  void sendKey(String data) {
    _send(data);
  }

  void _handleInput(String data) {
    if (_disposed) return;
    var payload = data;
    if (ctrl && data.length == 1) {
      final code = data.toUpperCase().codeUnitAt(0);
      if (code >= 0x40 && code <= 0x5f) {
        payload = String.fromCharCode(code & 0x1f);
      }
      ctrl = false;
      _notify();
    } else if (alt && data.isNotEmpty) {
      payload = '\x1b$data';
      alt = false;
      _notify();
    }
    _send(payload);
  }

  void _send(String data) {
    _shell?.stdin.add(Uint8List.fromList(utf8.encode(data)));
  }

  void _attachTerminal() {
    terminal.onOutput = _handleInput;
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _shell?.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };
  }

  void _resizeSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      _shell?.resizeTerminal(terminal.viewWidth, terminal.viewHeight);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _stdout?.cancel();
    try {
      _shell?.close();
    } catch (_) {}
    focusNode.dispose();
    super.dispose();
  }
}
