import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_language.dart';
import '../../core/app_session_manager.dart';
import '../../core/connection_state.dart';
import '../../core/host_session.dart';
import '../../data/app_settings.dart';
import '../../data/workspace_session.dart';
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

/// Authentication flow of the embedded opencode web UI.
enum _WorkspaceAuth {
  /// Resolving the stored cookie / preparing the page.
  checking,

  /// The page can be opened with the cookie the WebView already holds.
  verified,

  /// A one-time pairing link is driving the login in the web UI.
  pairing,

  /// Something failed; the view shows the reason and a retry action.
  failed,
}

class _HostWorkspaceViewState extends State<_HostWorkspaceView> {
  final AppSettings _settings = AppSettings();
  final WorkspaceStateStore _stateStore = WorkspaceStateStore();
  bool _languageListenerAdded = false;
  WebViewController? _webView;
  String? _currentUrl;
  String? _savedUrl;
  bool _savedUrlLoaded = false;
  Timer? _saveUrlDebounce;
  bool _autoBlurKeyboard = true;

  /// Authentication flow for this host's web view. `failed` is a first-class
  /// state: every failure surfaces a message and a retry entry, so a blank
  /// page can never be the final state.
  _WorkspaceAuth _auth = _WorkspaceAuth.checking;
  String? _target;
  String? _failure;
  int _loadAttempts = 0;
  bool _entered = false;

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

  /// Reports whether the loaded page actually rendered. A blank body or a
  /// login screen means the session is not usable even though a cookie was
  /// present.
  static const _pageHealthScript = r'''
    (function(){
      try {
        var href = location.href;
        if (window.__tdHealthHref === href) return;
        window.__tdHealthHref = href;
        // Give the SPA a moment to render before judging the page.
        setTimeout(function(){
          try {
            if (location.href !== href) return;
            var text = (document.body && document.body.innerText || '')
              .replace(/\s+/g, ' ').trim();
            var loginLike = /pairing link|连接到服务器|Connect to server/i.test(text);
            var pairError = /expired or already used|opencode pair/i.test(text);
            var state = text.length < 20
              ? 'empty'
              : (pairError ? 'pairerror' : (loginLike ? 'login' : 'ok'));
            TinyDeskPage.postMessage(state);
          } catch (e) {
            TinyDeskPage.postMessage('ok');
          }
        }, 1500);
      } catch (e) {}
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
    // Do not retry on idle: restore()/openHost already kicked a connect and
    // a duplicate attempt would generate a second pairing link.
    if (_session.phase == ConnectionPhase.failed) {
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
    if (snapshot.phase == ConnectionPhase.ready && !_entered) {
      _entered = true;
      unawaited(_enterWorkspace().timeout(
        const Duration(seconds: 45),
        onTimeout: () => _fail(AppL10n.t.connectionLost),
      ));
    } else if (snapshot.phase != ConnectionPhase.ready) {
      _entered = false;
    }
    if (mounted) setState(() {});
  }

  void _fail(String reason) {
    if (!mounted) return;
    setState(() {
      _auth = _WorkspaceAuth.failed;
      _failure = reason;
    });
  }

  /// The URL to open after (re)connecting: the saved page when it belongs
  /// to this host's loopback origin, otherwise the UI root.
  Future<String> _restoreTarget() async {
    if (!_savedUrlLoaded) {
      _savedUrl = await _stateStore.loadUrl(_host.id);
      _savedUrlLoaded = true;
    }
    final saved = _savedUrl;
    if (isRestorableUrl(saved, _host.localPort)) {
      return saved!;
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

  void _ensureWebView() {
    _webView ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'TinyDeskPage',
        onMessageReceived: (message) => _onPageHealth(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            _currentUrl = change.url;
            _scheduleSaveUrl(change.url);
            if (_auth == _WorkspaceAuth.pairing) {
              unawaited(_completePairing(change.url));
            }
          },
          onWebResourceError: (error) {
            debugPrint(
              'OC web error: ${error.errorCode} ${error.description} ${error.url}',
            );
            // -999 is a cancelled navigation (we redirected it ourselves).
            if (error.isForMainFrame == true && error.errorCode != -999) {
              _fail(AppL10n.t.connectionLost);
            }
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
            _webView?.runJavaScript(_pageHealthScript);
          },
        ),
      );
  }

  /// Single entry point for showing this host's web UI. Reuses the WebView
  /// session when it is still valid and otherwise drives the pairing login.
  Future<void> _enterWorkspace({bool isRetry = false}) async {
    _autoBlurKeyboard = await _settings.autoBlurKeyboard();
    _ensureWebView();
    if (!mounted) return;
    setState(() {
      _auth = _WorkspaceAuth.checking;
      _failure = null;
      if (!isRetry) _loadAttempts = 0;
    });

    final origin = 'http://127.0.0.1:${_host.localPort}';
    final target = await _restoreTarget();
    _target = target;

    final cookie = await const WebData().sessionCookie(_host.localPort);
    if (cookie != null && await _cookieStillValid(origin, cookie)) {
      // A saved session page may have been deleted on the server: fall back
      // to the UI root instead of showing an error page.
      _target = await _resolveTarget(origin, target);
      _auth = _WorkspaceAuth.verified;
      if (!mounted) return;
      setState(() {});
      await _webView!.loadRequest(Uri.parse(_target!));
      return;
    }

    // Not authenticated: get a one-time link and let opencode's own web UI
    // perform the login. The app never parses the auth response.
    String? link;
    try {
      link = await _session.connection.session?.createPairLink(origin);
    } catch (_) {}
    final pairUri = link == null ? null : Uri.tryParse(link);
    if (pairUri == null) {
      _fail(AppL10n.t.connectionNotReady);
      return;
    }
    _auth = _WorkspaceAuth.pairing;
    if (!mounted) return;
    setState(() {});
    await _webView!.loadRequest(pairUri);
  }

  /// Called when the WebView leaves the one-time pairing page: the login
  /// finished. The link is consumed at this point and must never be reused.
  Future<void> _completePairing(String? url) async {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || uri.path.startsWith('/auth/connect')) return;
    _auth = _WorkspaceAuth.verified;
    if (!mounted) return;
    setState(() {});
    final origin = 'http://127.0.0.1:${_host.localPort}';
    final target = _target == null ? null : await _resolveTarget(origin, _target!);
    _target = target;
    if (target != null && url != target) {
      await _webView?.loadRequest(Uri.parse(target));
    }
  }

  /// The saved page may be gone (session deleted on the server). Probe it
  /// first and fall back to the UI root on 404.
  Future<String> _resolveTarget(String origin, String target) async {
    if (target == origin || target == '$origin/') return '$origin/';
    final exists = await _targetExists(target);
    if (exists) return target;
    _savedUrl = '$origin/';
    unawaited(_stateStore.saveUrl(_host.id, '$origin/'));
    return '$origin/';
  }

  Future<bool> _targetExists(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final cookie = await const WebData().sessionCookie(_host.localPort);
      if (cookie != null) {
        request.headers.set(
          HttpHeaders.cookieHeader,
          '${cookie.key}=${cookie.value}',
        );
      }
      final response = await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      return response.statusCode != 404;
    } catch (_) {
      // Network hiccups are not 404s; keep the saved page.
      return true;
    } finally {
      client.close(force: true);
    }
  }

  /// Page health report from the web view. An empty page or a login page
  /// after a successful auth means something went wrong: retry once through
  /// the entry point, then surface a failure instead of a blank screen.
  void _onPageHealth(String state) {
    if (state == 'ok') return;
    if (state == 'pairerror') {
      // The one-time link was rejected by the server.
      _fail(AppL10n.t.pairingLinkExpired);
      return;
    }
    // During the pairing login the page legitimately shows a login screen.
    if (_auth == _WorkspaceAuth.pairing) return;
    if (_loadAttempts < 1) {
      _loadAttempts++;
      unawaited(_enterWorkspace(isRetry: true).timeout(
        const Duration(seconds: 45),
        onTimeout: () => _fail(AppL10n.t.connectionLost),
      ));
      return;
    }
    _fail(AppL10n.t.pageLoadFailed);
  }

  /// A stored cookie can outlive the server session (service restart, expiry).
  /// Verifying it avoids opening an unauthenticated page that renders blank.
  Future<bool> _cookieStillValid(String origin, MapEntry<String, String> cookie) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse('$origin/api/session'));
      request.headers.set(
        HttpHeaders.cookieHeader,
        '${cookie.key}=${cookie.value}',
      );
      final response = await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  void dispose() {
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
    if (_auth == _WorkspaceAuth.failed) {
      return _ErrorBody(
        message: _failure ?? AppL10n.t.pageLoadFailed,
        onRetry: () => unawaited(_enterWorkspace()),
      );
    }
    final webView = _webView;
    if (webView != null) {
      return Stack(
        children: [
          WebViewWidget(controller: webView),
          if (_auth == _WorkspaceAuth.checking)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x00000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      );
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
