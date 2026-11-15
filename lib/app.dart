import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_session_manager.dart';
import 'core/session_scope.dart';
import 'core/theme.dart';
import 'data/host_repository.dart';
import 'data/host_store.dart';
import 'data/private_key_store.dart';
import 'features/documents/floating_file_browser_host.dart';
import 'features/terminal/floating_terminal_host.dart';
import 'features/workspace/workspace_screen.dart';
import 'platform/window_close.dart';

class OpenCodeApp extends StatefulWidget {
  const OpenCodeApp({
    super.key,
    this.repository,
    this.keyStore,
    this.session,
  });

  final HostRepository? repository;
  final PrivateKeyStore? keyStore;
  final AppSessionManager? session;

  @override
  State<OpenCodeApp> createState() => _OpenCodeAppState();
}

class _OpenCodeAppState extends State<OpenCodeApp> {
  late final AppSessionManager _session =
      widget.session ?? AppSessionManager();
  late final bool _ownsSession = widget.session == null;
  late final HostRepository _repository =
      widget.repository ?? HostRepository(SharedPreferencesHostStore());
  late final PrivateKeyStore _keyStore = widget.keyStore ?? PrivateKeyStore();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _quitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    // Move any plaintext keys left by older builds into secure storage.
    unawaited(_keyStore.migrateAll());
    // Restore the sessions that were open when the app last exited.
    unawaited(
      _session.restore(repository: _repository, keyStore: _keyStore),
    );
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      WindowCloseHandler.register(_handleWindowClose);
    }
  }

  /// macOS red close button: the visible terminal panel is the topmost
  /// layer, then any pushed page, and only at the session root does it ask
  /// before quitting the whole app.
  Future<void> _handleWindowClose() async {
    // The floating terminal is rendered above the navigator, so it must be
    // handled first — otherwise a dialog would appear behind it.
    final terminal = _session.activeSession?.terminal;
    if (terminal != null && terminal.visible) {
      await terminal.close();
      return;
    }
    // The file browser is the next overlay layer: collapse it before the
    // navigator reacts so its state is not skipped.
    if (_session.handleFileBrowserBack()) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      await WindowCloseHandler.confirmClose();
      return;
    }
    if (navigator.canPop()) {
      // Let the top page run its own close confirmation (PopScope).
      await navigator.maybePop();
      return;
    }
    if (_quitDialogOpen) return;
    final context = _navigatorKey.currentContext;
    if (context == null) {
      await WindowCloseHandler.confirmClose();
      return;
    }
    _quitDialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出方寸台？'),
        content: const Text('所有会话连接将被断开。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    _quitDialogOpen = false;
    if (confirmed == true) {
      await WindowCloseHandler.confirmClose();
    }
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      WindowCloseHandler.unregister();
    }
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      manager: _session,
      child: MaterialApp(
        title: '方寸台',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        builder: (context, child) => Stack(
          children: [
            if (child != null) Positioned.fill(child: child),
            Positioned.fill(
              child: FloatingFileBrowserHost(manager: _session),
            ),
            Positioned.fill(
              child: FloatingTerminalHost(manager: _session),
            ),
          ],
        ),
        home: WorkspaceScreen(
          session: _session,
          repository: _repository,
          keyStore: _keyStore,
        ),
      ),
    );
  }
}
