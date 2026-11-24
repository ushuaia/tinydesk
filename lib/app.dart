import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_language.dart';
import 'session/app_session_manager.dart';
import 'session/session_scope.dart';
import 'session/window_chrome.dart';
import 'core/theme.dart';
import 'data/host_repository.dart';
import 'data/host_store.dart';
import 'data/private_key_store.dart';
import 'features/documents/floating_file_browser_host.dart';
import 'features/terminal/floating_terminal_host.dart';
import 'features/workspace/workspace_screen.dart';
import 'l10n/gen/app_localizations.dart';
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
  final AppLanguageController _language = AppLanguageController();
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
      WindowCloseHandler.register(
        _handleWindowClose,
        onMinimizeRequested: _minimizeOverlay,
      );
    }
  }

  /// macOS yellow light: collapses the window that is actually on screen into
  /// its floating ball. Returns false on ordinary pages so the native
  /// miniaturize runs instead. Balls are ignored: a minimized overlay is not
  /// something to minimize again.
  Future<bool> _minimizeOverlay() async {
    final session = _session.activeSession;
    switch (frontWindowOf(session?.terminal, session?.fileBrowser)) {
      case FrontWindow.terminal:
        session!.terminal.minimize();
        return true;
      case FrontWindow.fileBrowser:
        session!.fileBrowser.minimize();
        return true;
      case FrontWindow.none:
        return false;
    }
  }

  /// macOS red close button: closes the window that is on screen, then any
  /// pushed page, and only at the session root does it ask before quitting.
  /// Balls are ignored — a minimized overlay is already out of the way.
  Future<void> _handleWindowClose() async {
    final session = _session.activeSession;
    switch (frontWindowOf(session?.terminal, session?.fileBrowser)) {
      case FrontWindow.terminal:
        await session!.terminal.close();
        return;
      case FrontWindow.fileBrowser:
        // Asks the page first: unsaved edits can veto the close.
        await session!.fileBrowser.requestClose();
        return;
      case FrontWindow.none:
        break;
    }
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
    if (context == null || !context.mounted) {
      await WindowCloseHandler.confirmClose();
      return;
    }
    _quitDialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.t.quitTitle),
        content: Text(AppL10n.t.quitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.t.quit),
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
      child: ListenableBuilder(
        listenable: _language,
        builder: (context, _) => MaterialApp(
          title: 'TinyDesk',
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: _language.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          builder: (context, child) {
            AppL10n.update(AppLocalizations.of(context));
            // With the system title bar merged into the surface, the main
            // UI must clear the macOS traffic lights; the floating overlays
            // draw their own headers with a leading inset instead. The clear
            // zone is painted in the AppBar colour so it blends with the
            // page top instead of showing a colour seam.
            final topInset =
                defaultTargetPlatform == TargetPlatform.macOS ? 28.0 : 0.0;
            final theme = Theme.of(context);
            final appBarColor = theme.appBarTheme.backgroundColor ??
                theme.colorScheme.surface;
            return Stack(
              children: [
                if (child != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: appBarColor,
                      child: Padding(
                        padding: EdgeInsets.only(top: topInset),
                        child: child,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: FloatingFileBrowserHost(manager: _session),
                ),
                Positioned.fill(
                  child: FloatingTerminalHost(manager: _session),
                ),
              ],
            );
          },
          home: WorkspaceScreen(
            session: _session,
            language: _language,
            repository: _repository,
            keyStore: _keyStore,
          ),
        ),
      ),
    );
  }
}
