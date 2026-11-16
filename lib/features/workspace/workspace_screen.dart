import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_language.dart';
import '../../core/app_session_manager.dart';
import '../../core/connection_state.dart';
import '../../core/host_session.dart';
import '../../data/app_settings.dart';
import '../../data/favorite_sync.dart';
import '../../data/host.dart';
import '../../data/host_repository.dart';
import '../../data/private_key_store.dart';
import '../../data/workspace_state_store.dart';
import '../../platform/web_data.dart';
import '../connect/connect_page.dart';
import '../documents/document_opener.dart';
import '../documents/favorites_page.dart';
import '../hosts/host_list_screen.dart';
import 'opencode_upgrade_dialog.dart';
import 'workspace_page.dart';

/// Multi-host workspace container.
///
/// Every open session keeps its own web view in an [IndexedStack]; switching
/// hosts only changes the visible index, so page state, cookies, scroll
/// position and editing drafts survive switches. Sessions themselves are
/// owned by [AppSessionManager] and are only closed explicitly.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.session,
    required this.language,
    this.initialHostId,
    required this.repository,
    required this.keyStore,
  });

  final AppSessionManager session;
  final AppLanguageController language;
  final String? initialHostId;
  final HostRepository repository;
  final PrivateKeyStore keyStore;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final Map<String, GlobalKey<_HostWorkspaceViewState>> _viewKeys = {};
  bool _showHosts = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onManagerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialHostId = widget.initialHostId;
      if (mounted &&
          initialHostId != null &&
          widget.session.hasSession(initialHostId)) {
        widget.session.activate(initialHostId);
      }
    });
  }

  void _onManagerChanged() {
    if (mounted) setState(() {});
  }

  GlobalKey<_HostWorkspaceViewState> _keyFor(String hostId) =>
      _viewKeys.putIfAbsent(hostId, GlobalKey<_HostWorkspaceViewState>.new);

  Future<void> _closeTab(String hostId) async {
    final session = widget.session.sessions
        .where((s) => s.host.id == hostId)
        .firstOrNull;
    if (session == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.t.closeTabTitle(session.host.name)),
        content: Text(AppL10n.t.closeTabBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.t.close),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.session.closeSession(hostId);
  }

  Future<void> _handleBack(String hostId) async {
    if (_showHosts) {
      setState(() => _showHosts = false);
      return;
    }
    // The floating file browser sits above everything: back minimizes it
    // before the web view or the host list react.
    if (widget.session.handleFileBrowserBack()) return;
    final handled =
        await _keyFor(hostId).currentState?.handleBack() ?? false;
    // The workspace is the app root: leaving it means showing the embedded
    // host list (the session launcher), not popping a route.
    if (!handled && mounted) setState(() => _showHosts = true);
  }

  Future<void> _openUpgrade() async {
    final session = widget.session.activeSession;
    final tunnel = session?.connection.session;
    if (session == null || tunnel == null || !session.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.connectionNotReady)),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => OpencodeUpgradeDialog(session: tunnel),
    );
  }

  Future<void> _openTerminal(HostSession session) async {
    if (!session.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.connectionNotReady)),
      );
      return;
    }
    await widget.session.showTerminal();
  }

  /// Recent documents live behind their own toolbar tool, independent of
  /// the host navigation module.
  Future<void> _openFavorites() async {
    final opener = DocumentOpener(
      repository: widget.repository,
      keyStore: widget.keyStore,
      manager: widget.session,
    );
    final hosts = await widget.repository.all();
    final hostNames = {for (final host in hosts) host.id: host.name};
    if (!mounted) return;
    final sync = FavoriteSync(manager: widget.session);
    final index = sync.index;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FavoritesPage(
          load: index.load,
          sync: sync.syncAll,
          onOpen: (doc) => opener.open(context, doc),
          onRemove: (doc) => index.remove(
            hostId: doc.hostId ?? '',
            path: doc.path,
          ),
          onClear: index.clearAll,
          subtitleFor: (doc) =>
              '${hostNames[doc.hostId] ?? AppL10n.t.unknownHost} · ${doc.path}',
        ),
      ),
    );
  }

  /// The embedded host list is the session launcher (Chrome-style "new tab"
  /// page): picking a host opens or activates its session and switches the
  /// content area back to the session views.
  Widget _hostListPanel() {
    return HostListScreen(
      repository: widget.repository,
      keyStore: widget.keyStore,
      language: widget.language,
      embedded: true,
      onHostOpened: () {
        if (mounted) setState(() => _showHosts = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.session;
    final sessions = manager.sessions;
    final empty = sessions.isEmpty;
    final showList = _showHosts || empty;
    final active = manager.activeSession ?? sessions.firstOrNull;
    final activeIndex = active == null
        ? 0
        : sessions
            .indexWhere((session) => session.host.id == active.host.id)
            .clamp(0, sessions.length - 1);
    final panelOpen = _showHosts || empty;
    return WorkspacePage(
      snapshot:
          active?.snapshot ?? const ConnectionSnapshot(phase: ConnectionPhase.idle),
      tabs: [
        for (final session in sessions)
          WorkspaceTab(
            hostId: session.host.id,
            name: session.host.name,
            phase: session.phase,
          ),
      ],
      activeHostId:
          panelOpen ? WorkspacePage.newTabHostId : active?.host.id,
      // The tool buttons belong to a session; the new-tab page hides them.
      showSessionActions: !panelOpen,
      onSelectTab: (hostId) {
        setState(() => _showHosts = false);
        manager.activate(hostId);
      },
      onCloseTab: (hostId) => unawaited(_closeTab(hostId)),
      onAddHost: () {
        if (panelOpen) return; // the new-tab page is already showing
        setState(() => _showHosts = true);
      },
      // System back (mobile gesture) keeps the tiered behaviour.
      onBack:
          active == null ? null : () => unawaited(_handleBack(active.host.id)),
      onFiles: () {
        if (active == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppL10n.t.noOpenSessions)),
          );
          return;
        }
        unawaited(
          _keyFor(active.host.id).currentState?.openFiles() ??
              Future<void>.value(),
        );
      },
      onDocuments: () => unawaited(_openFavorites()),
      onUpgrade: () => unawaited(_openUpgrade()),
      onTerminal: () {
        if (active == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppL10n.t.noOpenSessions)),
          );
          return;
        }
        unawaited(_openTerminal(active));
      },
      onRetry: active == null
          ? null
          : () => unawaited(manager.retry(active.host.id)),
      body: showList
          ? _hostListPanel()
          : IndexedStack(
              index: activeIndex,
              children: [
                for (final session in sessions)
                  _HostWorkspaceView(
                    key: _keyFor(session.host.id),
                    manager: manager,
                    session: session,
                    language: widget.language,
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    widget.session.removeListener(_onManagerChanged);
    super.dispose();
  }
}

/// One host's web view and connection-driven UI.
class _HostWorkspaceView extends StatefulWidget {
  const _HostWorkspaceView({
    super.key,
    required this.manager,
    required this.session,
    required this.language,
  });

  final AppSessionManager manager;
  final HostSession session;
  final AppLanguageController language;

  @override
  State<_HostWorkspaceView> createState() => _HostWorkspaceViewState();
}

class _HostWorkspaceViewState extends State<_HostWorkspaceView> {
  final AppSettings _settings = AppSettings();
  final WorkspaceStateStore _stateStore = WorkspaceStateStore();
  bool _languageListenerAdded = false;
  WebViewController? _webView;
  String? _loadedPairUrl;
  String? _currentUrl;
  String? _pendingTarget;
  bool _pairingLogin = false;
  Timer? _pairLoginTimeout;
  int _pairLoginRetries = 0;
  String? _savedUrl;
  bool _savedUrlLoaded = false;
  Timer? _saveUrlDebounce;
  ConnectionPhase? _lastPhase;
  bool _autoBlurKeyboard = true;

  /// 避免进入会话时自动弹出输入法。
  ///
  /// 只处理「页面自动聚焦」：用户主动点过输入框后不再 blur。
  /// SPA 切换会话时重置标记，再尝试收起一次。
  static const _keyboardBridgeScript = r'''
(function () {
  if (window.__ocKeyboardBridge) return;
  window.__ocKeyboardBridge = true;

  var userInteracted = false;
  var lastHref = location.href;

  var originalFocus = HTMLElement.prototype.focus;
  HTMLElement.prototype.focus = function () {
    if (!userInteracted && this.isContentEditable) {
      return;
    }
    return originalFocus.apply(this, arguments);
  };

  document.addEventListener('pointerdown', function (e) {
    var target = e.target;
    if (target && (target.isContentEditable || target.tagName === 'TEXTAREA' || target.tagName === 'INPUT')) {
      userInteracted = true;
    }
  }, true);

  function blurActive() {
    if (userInteracted) return;
    var el = document.activeElement;
    if (el && (el.isContentEditable || el.tagName === 'TEXTAREA' || el.tagName === 'INPUT')) {
      el.blur();
    }
  }

  function checkRoute() {
    if (location.href === lastHref) return;
    lastHref = location.href;
    userInteracted = false;
    setTimeout(blurActive, 0);
  }

  new MutationObserver(checkRoute).observe(document.body, {
    childList: true,
    subtree: true
  });
  setInterval(checkRoute, 400);
  setTimeout(blurActive, 0);
})();
''';

  /// Stops the SPA from treating the Enter that commits a CJK IME
  /// composition as a submit. The IME still commits; the key event is only
  /// kept away from the page's handlers.
  static const _imeGuardScript = r'''
(function () {
  if (window.__ocImeGuard) return;
  window.__ocImeGuard = true;

  var composing = false;
  var lastCompositionEnd = 0;

  window.addEventListener('compositionstart', function () {
    composing = true;
  }, true);

  window.addEventListener('compositionend', function () {
    composing = false;
    lastCompositionEnd = Date.now();
  }, true);

  window.addEventListener('keydown', function (e) {
    var isEnter = e.key === 'Enter' || e.keyCode === 13;
    if (!isEnter) return;
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    var imeEnter = composing || e.isComposing === true || e.keyCode === 229 ||
        (Date.now() - lastCompositionEnd) < 80;
    if (!imeEnter) return;
    // Keep the IME commit but hide the key from submit handlers.
    e.stopImmediatePropagation();
  }, true);
})();
''';

  /// Desktop windows are wide enough that the web UI's centered max-width
  /// layout wastes space. Mobile keeps its own layout.
  static const _wideLayoutScript = r'''
(function () {
  function apply() {
    if (document.getElementById('oc-wide-layout')) return;
    var style = document.createElement('style');
    style.id = 'oc-wide-layout';
    style.textContent = [
      'html, body { max-width: none !important; width: 100% !important; }',
      '#root { max-width: none !important; width: 100% !important; }',
      'main { max-width: none !important; width: 100% !important; }',
      // opencode uses a fixed 280px + 720px grid; let the content column grow.
      // Keep this scoped so session rows keep their own internal flex layout.
      '.scroll-view__viewport > .grid { max-width: none !important; width: 100% !important; margin-left: 0 !important; margin-right: 0 !important; grid-template-columns: 280px minmax(0, 1fr) !important; }',
      '.scroll-view__viewport section { max-width: none !important; width: 100% !important; }',
      '[class*="max-w-"] { max-width: none !important; }',
      '[class*="mx-auto"] { margin-left: 0 !important; margin-right: 0 !important; }'
    ].join('\n');
    document.head.appendChild(style);
  }

  apply();
  // The SPA may replace the head while routing; re-apply defensively.
  setInterval(apply, 2000);
})();
''';

  HostSession get _session => widget.session;
  Host get _host => _session.host;

  @override
  void initState() {
    super.initState();
    _session.connection.addListener(_onStateChanged);
    if (_session.phase == ConnectionPhase.idle ||
        _session.phase == ConnectionPhase.failed) {
      unawaited(widget.manager.retry(_host.id));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onStateChanged();
    });
    _ensureLanguageListener();
  }

  void _ensureLanguageListener() {
    if (_languageListenerAdded) return;
    _languageListenerAdded = true;
    widget.language.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    _syncOpencodeLanguage();
  }

  /// Keeps the embedded opencode web UI in the app language. opencode
  /// reads its own locale from localStorage
  /// (`opencode.global.dat:language`, a `{"locale":"xx"}` JSON). Write it
  /// before use and on switches; the reload inside the script happens
  /// only when the stored locale differs.
  static String _opencodeLanguageScript(String code) => """
    (function(){
      var target = '$code';
      try {
        var raw = localStorage.getItem('opencode.global.dat:language');
        var current = raw ? (JSON.parse(raw).locale || null) : null;
        if (current !== target) {
          localStorage.setItem('opencode.global.dat:language', JSON.stringify({locale: target}));
          location.reload();
        }
      } catch (e) {}
    })();
  """;

  void _syncOpencodeLanguage() {
    if (_webView == null) return;
    _webView
        ?.runJavaScript(_opencodeLanguageScript(widget.language.resolvedCode));
  }

  void _onStateChanged() {
    final snapshot = _session.connection.state;
    final pairUrl = snapshot.pairUrl;
    final becameReady = snapshot.phase == ConnectionPhase.ready &&
        _lastPhase != ConnectionPhase.ready;
    _lastPhase = snapshot.phase;
    // Reload when pairing changed (first connect) or after a reconnect so
    // the web view is re-authorised and the saved scene is restored.
    if (snapshot.phase == ConnectionPhase.ready) {
      final needsLogin =
          pairUrl != null && (becameReady || pairUrl != _loadedPairUrl);
      // After the login the link is cleared; a rebuilt view (tab switch)
      // then restores the saved page using the cookie already in the
      // WebView store.
      final needsRestore = pairUrl == null && becameReady;
      if (needsLogin || needsRestore) {
        if (pairUrl != null) _loadedPairUrl = pairUrl;
        unawaited(_loadWorkspace(snapshot));
      }
    }
    if (mounted) setState(() {});
  }

  /// The URL to open after (re)connecting: the saved page when it belongs
  /// to this host's loopback origin, otherwise the UI root.
  Future<String> _restoreTarget() async {
    if (!_savedUrlLoaded) {
      _savedUrl = await _stateStore.loadUrl(_host.id);
      _savedUrlLoaded = true;
    }
    final saved = _savedUrl;
    if (saved != null) {
      final uri = Uri.tryParse(saved);
      if (uri != null &&
          uri.host == '127.0.0.1' &&
          uri.port == _host.localPort &&
          uri.path.startsWith('/') &&
          !uri.path.startsWith('/auth/connect')) {
        return saved;
      }
    }
    return 'http://127.0.0.1:${_host.localPort}/';
  }

  void _scheduleSaveUrl(String? url) {
    if (url == null) return;
    // The pairing link is one-time: persisting it would make the next
    // restore navigate to an already-consumed link.
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.startsWith('/auth/connect')) return;
    _saveUrlDebounce?.cancel();
    _saveUrlDebounce = Timer(const Duration(milliseconds: 600), () {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.host != '127.0.0.1' ||
          uri.port != _host.localPort) {
        return;
      }
      _savedUrl = url;
      unawaited(_stateStore.saveUrl(_host.id, url));
    });
  }

  Future<void> _loadWorkspace(ConnectionSnapshot snapshot) async {
    _autoBlurKeyboard = await _settings.autoBlurKeyboard();

    _webView ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            _currentUrl = change.url;
            _scheduleSaveUrl(change.url);
            unawaited(_handlePairLogin(change.url));
          },
          onPageFinished: (_) {
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              _webView?.runJavaScript(_wideLayoutScript);
            }
            _syncOpencodeLanguage();
            _webView?.runJavaScript(_imeGuardScript);
            if (_autoBlurKeyboard) {
              _webView?.runJavaScript(_keyboardBridgeScript);
            }
          },
        ),
      );
    if (!mounted) return;
    setState(() {});

    if (!mounted) return;

    // Every host uses its own localPort, and opencode names its session
    // cookie after that port, so cookies from different hosts coexist
    // instead of overwriting each other. Restore the last page (session)
    // this host was showing, or the UI root on first visit.
    final target = await _restoreTarget();

    // Authentication runs inside the WebView: open the one-time pairing
    // link and let opencode's own web UI perform the login. Nothing here
    // parses the auth response, so upstream protocol changes (Set-Cookie →
    // JSON token → whatever comes next) require no app change.
    final pairLink = snapshot.pairUrl;
    final pairUri = pairLink == null ? null : Uri.tryParse(pairLink);
    if (pairUri != null && pairUri.path.startsWith('/auth/connect')) {
      _pendingTarget = target;
      _pairingLogin = true;
      _pairLoginTimeout?.cancel();
      // If the login never leaves the pairing page (expired link, service
      // restarted mid-flow …), reconnect to obtain a fresh one-time link.
      _pairLoginTimeout = Timer(const Duration(seconds: 12), () {
        if (!mounted || !_pairingLogin) return;
        _pairingLogin = false;
        if (_pairLoginRetries >= 2) return; // leave the error page visible
        _pairLoginRetries++;
        unawaited(widget.manager.retry(_host.id));
      });
      await _webView!.loadRequest(pairUri);
      return;
    }

    await _webView!.loadRequest(Uri.parse(target));
  }

  /// Called when the WebView finishes the pairing login (it navigates away
  /// from /auth/connect). Reads the session cookie back from the WebView so
  /// native HTTP features can use it, then opens the restored page.
  Future<void> _handlePairLogin(String? url) async {
    if (!_pairingLogin) return;
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || uri.path.startsWith('/auth/connect')) return;
    _pairingLogin = false;
    _pairLoginRetries = 0;
    _pairLoginTimeout?.cancel();
    _pairLoginTimeout = null;
    final target = _pendingTarget;
    _pendingTarget = null;
    final origin = 'http://127.0.0.1:${_host.localPort}/';
    // The WebView writes its cookie store asynchronously right after the
    // redirect, so retry briefly. Match this host's port-scoped cookie
    // first: the shared WebView store also holds cookies of other hosts.
    String? cookieName;
    String? cookieValue;
    for (var attempt = 0; attempt < 4; attempt++) {
      final cookies = await const WebData().sessionCookies(origin);
      final exact = cookies['opencode_session_${_host.localPort}'];
      if (exact != null && exact.isNotEmpty) {
        cookieName = 'opencode_session_${_host.localPort}';
        cookieValue = exact;
        break;
      }
      final fallback = cookies.entries
          .where((e) => e.key.startsWith('opencode_session_'))
          .firstOrNull;
      if (fallback != null && fallback.value.isNotEmpty) {
        cookieName = fallback.key;
        cookieValue = fallback.value;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    // The link is consumed now — clear it before anything else can reuse
    // it, even when the cookie read came back empty.
    _session.connection.completePairing(
      cookieName: cookieName,
      cookieValue: cookieValue,
    );
    if (!mounted || target == null) return;
    if (url != target) {
      await _webView?.loadRequest(Uri.parse(target));
    }
  }

  @override
  void dispose() {
    _pairLoginTimeout?.cancel();
    _saveUrlDebounce?.cancel();
    _session.connection.removeListener(_onStateChanged);
    super.dispose();
  }

  /// Returns true when the back action was handled inside the web view
  /// (session detail → list), false when the caller should pop the route.
  Future<bool> handleBack() async {
    final webView = _webView;
    if (webView == null) return false;
    // Back is app-level, not browser-history-based: a session detail view
    // returns to the session list, and from the list (or any other web UI
    // page) we leave the workspace back to the host list.
    final current = Uri.tryParse(_currentUrl ?? '');
    final inSession =
        current != null && current.pathSegments.contains('session');
    if (inSession) {
      final origin = current.replace(path: '/', query: '', fragment: '');
      _currentUrl = origin.toString();
      await webView.loadRequest(origin);
      return true;
    }
    return false;
  }

  Future<void> openFiles() async {
    // No project-picker dialogs: the floating window shows every host
    // project as a parallel tree root and the user expands what they need.
    if (widget.manager.fileBrowser == null ||
        _session.connection.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.connectionNotReady)),
      );
      return;
    }
    widget.manager.showFileBrowser();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _session.connection.state;
    if (snapshot.phase == ConnectionPhase.failed) {
      return _ErrorBody(
        message: snapshot.message ?? AppL10n.t.connectionFailedTitle,
        onRetry: () => unawaited(widget.manager.retry(_host.id)),
      );
    }
    final webView = _webView;
    if (webView != null) {
      return WebViewWidget(controller: webView);
    }
    if (snapshot.phase == ConnectionPhase.reconnecting) {
      return const SizedBox.shrink();
    }
    return ConnectView(snapshot: snapshot);
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: Text(AppL10n.t.retry)),
          ],
        ),
      ),
    );
  }
}
