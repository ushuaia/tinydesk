import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'viewer_localization.dart';

import '../../core/app_language.dart';

import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/reading_progress_store.dart';
import '../../data/markdown_images.dart';
import '../../data/remote_file.dart';
import '../../ssh/tunnel_session.dart';
import 'markdown_chunks.dart';
import 'document_editor_support.dart';
import 'reader_app_bar.dart';

/// ArkWeb returns JavaScript results as JSON-encoded strings, while other
/// platforms return native values. Unwrap up to two string layers.
Object? _unwrapJsResult(Object? raw) {
  var current = raw;
  for (var i = 0; i < 2; i++) {
    if (current is! String) break;
    final text = current.trim();
    if (text.isEmpty) return null;
    try {
      current = jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
  return current;
}

class MarkdownReaderPage extends StatefulWidget {
  const MarkdownReaderPage({
    super.key,
    required this.session,
    required this.file,
    required this.hostId,
    required this.projectRoot,
    this.userScope = '',
    this.embedded = false,
    this.onStateChanged,
    this.register,
  });

  final TunnelSession session;
  final RemoteFile file;
  final String hostId;
  final String projectRoot;
  final String userScope;

  /// Rendered inside the unified files page: no Scaffold/AppBar.
  final bool embedded;
  final VoidCallback? onStateChanged;
  final ValueChanged<MarkdownReaderPageState>? register;

  @override
  State<MarkdownReaderPage> createState() => MarkdownReaderPageState();
}

class MarkdownReaderPageState extends State<MarkdownReaderPage>
    with WidgetsBindingObserver {
  late final ReadingProgressStore _progressStore;

  HttpServer? _server;
  WebViewController? _webView;
  String? _error;
  bool _loading = true;
  double _zoom = 1.0;
  bool _disposed = false;
  bool _popping = false;
  bool _flushing = false;
  int? _lastSavedY;
  Timer? _pollTimer;
  Map<String, dynamic> _progressState = const {'kind': 'pixels', 'scrollY': 0};

  // Read / edit mode.
  List<String> _blocks = const [];
  String _buffer = '';
  String _savedText = '';
  DateTime? _lastModified;
  String? _baseDir;
  String _imageToken = '';
  bool _dirty = false;
  bool _editable = false;
  bool _editing = false;
  bool _saving = false;
  RemoteFile? _opened;
  String? _readOnlyReason;
  double _readingRatio = 0;

  bool get isDirty => _dirty;
  bool get isEditing => _editing;
  double get zoom => _zoom;

  /// True when the file changed on the server since it was loaded.
  Future<bool> checkExternalUpdate() async {
    if (_loading || _error != null || _editing) return false;
    final modified = await widget.session.statModified(widget.file.path);
    if (modified == null || _lastModified == null) return false;
    return modified.isAfter(_lastModified!);
  }

  /// Reloads the file from the server in reading mode. The caller must not
  /// invoke this while the document has unsaved edits.
  Future<void> reloadFromServer() async {
    if (_editing || _loading || _error != null || _server == null) return;
    try {
      final text = await widget.session.readText(widget.file.path);
      _lastModified =
          await widget.session.statModified(widget.file.path) ?? _lastModified;
      if (!mounted) return;
      setState(() {
        _buffer = text;
        _savedText = text;
        _blocks = _splitAndRewrite(text);
      });
      // Rebuild the WebView so the local asset server re-serves the new
      // blocks (same path as returning to reading mode), then restore
      // progress.
      _pollTimer?.cancel();
      try {
        final saved = await _progressStore
            .loadBestState(widget.hostId, widget.file.path)
            .timeout(const Duration(seconds: 2));
        if (saved != null) {
          _progressState = saved.state;
          _zoom = saved.fontScale;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _webView = _createWebView(_server!.port);
      });
    } catch (_) {}
  }

  Future<void> saveDocument() => _save();
  Future<void> toggleEditMode() => _toggleEdit();
  void zoomBy(double delta) => _setZoom(delta);
  Future<void> flushProgress() => _flushProgress();

  @override
  void initState() {
    super.initState();
    // Bind this state into the handle immediately, so its action closures
    // never depend on GlobalKey timing.
    widget.register?.call(this);
    _progressStore = ReadingProgressStore(
      session: widget.session,
      projectRoot: widget.projectRoot,
      userScope: widget.userScope,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepare());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_flushProgress());
    }
  }

  WebViewController _createWebView(int port) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('DocBridge', onMessageReceived: _onBridge);
    unawaited(
      controller.loadRequest(
        Uri.parse(
          'http://127.0.0.1:$port/markdown.html'
          '?fontScale=$_zoom'
          '${_editing ? '&mode=edit&pos=${_readingRatio.toStringAsFixed(4)}' : ''}',
        ),
      ),
    );
    return controller;
  }

  void _onBridge(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      if (data['type'] == 'change') {
        final text = data['text'] as String? ?? '';
        setState(() {
          _buffer = text;
          _dirty = text != _savedText;
        });
        widget.onStateChanged?.call();
        return;
      }
      if (data['type'] == 'progress') {
        data.remove('type');
        _progressStore.saveState(
          widget.hostId,
          widget.file.path,
          state: data,
          fontScale: _zoom,
        );
        return;
      }
      if (data['type'] == 'ready' && !_editing) {
        unawaited(_restoreNative());
      }
    } catch (_) {}
  }

  String _documentDirectory(String path) {
    final slash = path.lastIndexOf('/');
    if (slash <= 0) return '/';
    return path.substring(0, slash);
  }

  List<String> _splitAndRewrite(String text) {
    final dir = _baseDir;
    final blocks = splitMarkdown(text);
    if (dir == null) return blocks;
    return [
      for (final block in blocks)
        rewriteMarkdownImages(block, baseDir: dir, token: _imageToken),
    ];
  }

  Future<void> _serveImage(HttpRequest request) async {
    final token = request.uri.queryParameters['t'];
    final encoded = request.uri.queryParameters['p'];
    final dir = _baseDir;
    if (token != _imageToken || encoded == null || dir == null) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    try {
      final remote = utf8.decode(base64Url.decode(encoded));
      final extension = remote.contains('.')
          ? remote.substring(remote.lastIndexOf('.') + 1).toLowerCase()
          : '';
      if (!isInsideDirectory(remote, dir) ||
          !allowedImageExtensions.contains(extension)) {
        request.response.statusCode = HttpStatus.forbidden;
      } else {
        final bytes = await widget.session.readBytes(remote);
        if (bytes.length > 8 * 1024 * 1024) {
          request.response.statusCode = HttpStatus.requestEntityTooLarge;
        } else {
          request.response.headers.contentType =
              ContentType.parse(contentTypeForExtension(remote));
          request.response.add(bytes);
        }
      }
    } catch (_) {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }

  Future<void> _prepare() async {
    try {
      final textFuture = widget.session.readText(widget.file.path);
      final stateFuture = _progressStore.loadBestState(
        widget.hostId,
        widget.file.path,
      );
      final text = await textFuture;
      _buffer = text;
      _savedText = text;
      _lastModified = await widget.session.statModified(widget.file.path) ?? _lastModified;
      _opened = widget.file;
      _baseDir = _documentDirectory(widget.file.path);
      _imageToken = randomImageToken();
      _blocks = _splitAndRewrite(text);
      final editableBytes = utf8.encode(text).length;
      _editable = editableBytes <= DocumentEditorSupport.maxEditableBytes;
      _readOnlyReason = _editable ? null : AppL10n.t.fileTooLarge2MB;
      final state = await stateFuture;
      if (state != null) {
        _progressState = state.state;
        _zoom = state.fontScale;
      }

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        try {
          final path = request.uri.path;
          if (path == '/markdown') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'blocks': _blocks}));
          } else if (path == '/raw') {
            request.response.headers.contentType = ContentType.text;
            request.response.write(_buffer);
          } else if (path == '/markdown.html') {
            request.response.headers.contentType = ContentType.html;
            request.response.add(renderViewerHtml(await _asset('assets/viewer/markdown.html')));
          } else if (path == '/img') {
            await _serveImage(request);
          } else if (path == '/marked.min.js') {
            request.response.headers.contentType =
                ContentType('application', 'javascript');
            request.response.add(await _asset('assets/viewer/marked.min.js'));
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
        } catch (_) {
          request.response.statusCode = HttpStatus.internalServerError;
        } finally {
          await request.response.close();
        }
      });

      final webView = _createWebView(server.port);

      if (!mounted) {
        await server.close(force: true);
        return;
      }

      setState(() {
        _server = server;
        _webView = webView;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = AppL10n.t.loadFailed(error.toString());
        _loading = false;
      });
    }
  }

  Future<Uint8List> _asset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  void _setZoom(double delta) {
    final next = (_zoom + delta).clamp(0.6, 2.0);
    setState(() => _zoom = next);
    widget.onStateChanged?.call();
    _lastSavedY = null;
    _webView?.runJavaScript('setFontScale($next)');
    _progressStore.saveZoom(widget.hostId, widget.file.path, next);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_pollProgress());
    });
  }

  /// Reads ArkWeb's native scroll offset. This is the value the viewport is
  /// actually showing; JavaScript's `window.scrollY` can lag behind it while
  /// the user is flinging.
  Future<int?> _readNativeY() async {
    final webView = _webView;
    if (webView == null) return null;
    try {
      // `platform` is `OhosWebViewController` on HarmonyOS. Calling through
      // `dynamic` keeps this file free of a hard OHOS-only import, so plain
      // `flutter test` can still compile the widget tree.
      final dynamic platform = webView.platform;
      final dynamic position = await platform
          .getScrollPosition()
          .timeout(const Duration(seconds: 1));
      return (position.dy as num).round();
    } catch (_) {
      // Android, iOS and macOS controllers expose no native scroll API.
      // Their JS scrollY matches the viewport, so use it instead.
      try {
        final result = await webView
            .runJavaScriptReturningResult('window.scrollY')
            .timeout(const Duration(seconds: 1));
        final value = _unwrapJsResult(result);
        if (value is num) return value.round();
      } catch (_) {}
      return null;
    }
  }

  Future<void> _pollProgress() async {
    if (_flushing || _disposed) return;
    final y = await _readNativeY();
    if (y == null || y == _lastSavedY) return;
    _lastSavedY = y;
    await _progressStore.saveState(
      widget.hostId,
      widget.file.path,
      state: {'kind': 'native', 'scrollY': y, 'nativeY': y},
      fontScale: _zoom,
    );
  }

  Future<void> _flushProgress() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final y = await _readStableNativeY();
      if (y == null) return;
      _lastSavedY = y;
      _progressState = {
        'kind': 'native',
        'scrollY': y,
        'nativeY': y,
      };
      await _progressStore
          .saveState(
            widget.hostId,
            widget.file.path,
            state: {'kind': 'native', 'scrollY': y, 'nativeY': y},
            fontScale: _zoom,
            syncRemote: true,
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
    } finally {
      _flushing = false;
    }
  }

  /// Samples the native offset until two consecutive reads agree, so a fling
  /// that is still decelerating is not saved as the final position.
  Future<int?> _readStableNativeY() async {
    int? previous;
    for (var i = 0; i < 12; i++) {
      final y = await _readNativeY();
      if (y == null) return previous;
      if (previous != null && previous == y) return y;
      previous = y;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return previous;
  }

  /// Restores the saved offset through ArkWeb's native scroll API instead of
  /// relying on `window.scrollY`, then releases the viewer's save guard.
  Future<void> _restoreNative() async {
    if (_disposed) return;
    final webView = _webView;
    if (webView == null) return;
    final saved = _progressState['nativeY'] ?? _progressState['scrollY'];
    if (saved is num && saved > 0) {
      try {
        final dynamic platform = webView.platform;
        await platform
            .scrollTo(0, saved.round())
            .timeout(const Duration(seconds: 1));
        final dynamic position = await platform
            .getScrollPosition()
            .timeout(const Duration(seconds: 1));
        debugPrint(
          'RESTORE native want=${saved.round()} '
          'actual=${(position.dy as num).round()}',
        );
      } catch (_) {
        // Android, iOS and macOS: restore through JavaScript.
        try {
          await webView
              .runJavaScript('window.scrollTo(0, ${saved.round()})')
              .timeout(const Duration(seconds: 1));
        } catch (_) {}
      }
    }
    try {
      await webView.runJavaScript(
        'window.__ocFinishRestore && window.__ocFinishRestore()',
      );
    } catch (_) {}
    _startPolling();
  }

  /// Fraction (0..1) of the rendered document the reader is currently at.
  /// Falls back to the last saved progress when JS cannot be queried.
  Future<double> _readReadingRatio() async {
    try {
      final raw = await _webView
          ?.runJavaScriptReturningResult(
            'JSON.stringify({'
            'y: window.scrollY,'
            'h: document.body.scrollHeight,'
            'v: window.innerHeight'
            '})',
          )
          .timeout(const Duration(milliseconds: 1500));
      final text = raw?.toString() ?? '';
      final json = jsonDecode(
        text.replaceAll(RegExp(r'^"|"$'), '').replaceAll(r'\\"', '"'),
      ) as Map<String, dynamic>;
      final y = (json['y'] as num?)?.toDouble() ?? 0;
      final h = (json['h'] as num?)?.toDouble() ?? 0;
      final v = (json['v'] as num?)?.toDouble() ?? 0;
      final span = h - v;
      if (span <= 1) return 0;
      return (y / span).clamp(0.0, 1.0);
    } catch (_) {
      final saved = _progressState['scrollY'];
      if (saved is num && saved > 0) return 0;
      return 0;
    }
  }

  Future<void> _toggleEdit() async {
    if (_loading || _error != null || _server == null) return;
    if (!_editing && !_editable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_readOnlyReason ?? AppL10n.t.notEditable)),
      );
      return;
    }
    if (!_editing) {
      // Persist the reading position before switching surfaces (bounded so
      // a hung native call can never block the switch).
      try {
        await _flushProgress().timeout(const Duration(seconds: 5));
      } catch (_) {}
      _pollTimer?.cancel();
      _readingRatio = await _readReadingRatio();
      // Rebuild the WebView from scratch in edit mode (same code path as
      // opening the file; avoids in-page JS injection).
      setState(() {
        _editing = true;
        _webView = _createWebView(_server!.port);
      });
      widget.onStateChanged?.call();
      return;
    }
    // Back to reading: render the current buffer, then restore progress.
    _pollTimer?.cancel();
    _blocks = _splitAndRewrite(_buffer);
    // Refresh the progress snapshot: it may have been advanced by scrolling
    // before the edit switch.
    try {
      final saved = await _progressStore
          .loadBestState(widget.hostId, widget.file.path)
          .timeout(const Duration(seconds: 2));
      if (saved != null) {
        _progressState = saved.state;
        _zoom = saved.fontScale;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _editing = false;
      _webView = _createWebView(_server!.port);
    });
    widget.onStateChanged?.call();
    _startPolling();
  }

  Future<void> _save() async {
    if (_saving) return;
    final opened = _opened;
    if (opened == null) return;
    _saving = true;
    try {
      final changed = await DocumentEditorSupport.changedOnRemote(
        widget.session,
        opened,
      );
      if (changed && mounted) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppL10n.t.fileChangedRemotely),
            content: Text(AppL10n.t.overwriteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppL10n.t.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppL10n.t.overwrite),
              ),
            ],
          ),
        );
        if (overwrite != true) return;
      }
      await widget.session.writeText(widget.file.path, _buffer);
      if (!mounted) return;
      setState(() {
        _savedText = _buffer;
        _dirty = false;
        _opened = DocumentEditorSupport.withSavedContent(opened, _buffer);
      });
      widget.onStateChanged?.call();
      if (!widget.embedded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.t.saved)),
        );
      }
    } catch (error) {
      if (mounted && !widget.embedded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.t.saveFailed(error.toString()))),
        );
      }
    } finally {
      _saving = false;
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.t.unsavedChanges),
        content: Text(AppL10n.t.unsavedChangesFile(widget.file.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(AppL10n.t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(AppL10n.t.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(AppL10n.t.save),
          ),
        ],
      ),
    );
    if (action == 'save') {
      await _save();
      return !_dirty;
    }
    return action == 'discard';
  }

  Future<void> _handleBack() async {
    if (_popping) return;
    if (!await _confirmDiscard()) return;
    _popping = true;
    _pollTimer?.cancel();
    await _flushProgress();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _pollTimer?.cancel();
    unawaited(_flushProgress());
    _server?.close(force: true);
    super.dispose();
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!),
        ),
      );
    }
    return WebViewWidget(controller: _webView!);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _content();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleBack());
      },
      child: Scaffold(
        appBar: ReaderAppBar(
          title: widget.file.name,
          zoom: _zoom,
          onZoomOut: () => _setZoom(-0.1),
          onZoomIn: () => _setZoom(0.1),
          onBack: () => unawaited(_handleBack()),
          canZoomOut: _zoom > 0.6,
          canZoomIn: _zoom < 2.0,
          onToggleEdit: () => unawaited(_toggleEdit()),
          editing: _editing,
          onSave: () => unawaited(_save()),
          dirty: _dirty,
          showZoom: !_editing,
        ),
        body: _content(),
      ),
    );
  }
}
