import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/reading_progress_store.dart';
import '../../data/remote_file.dart';
import '../../ssh/tunnel_session.dart';
import 'reader_app_bar.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    super.key,
    required this.session,
    required this.file,
    required this.hostId,
    required this.projectRoot,
    this.userScope = '',
    this.embedded = false,
  });

  final TunnelSession session;
  final RemoteFile file;
  final String hostId;
  final String projectRoot;
  final String userScope;
  final bool embedded;

  @override
  State<PdfReaderPage> createState() => PdfReaderPageState();
}

class PdfReaderPageState extends State<PdfReaderPage>
    with WidgetsBindingObserver {
  static const _maxBytes = 100 * 1024 * 1024;

  late final ReadingProgressStore _progressStore;

  HttpServer? _server;
  Directory? _tempDir;
  WebViewController? _webView;
  String? _error;
  bool _loading = true;
  double _zoom = 1.0;
  bool _popping = false;
  bool _flushing = false;
  int? _lastSavedY;
  Timer? _pollTimer;

  double get zoom => _zoom;
  void zoomBy(double delta) => _setZoom(delta);
  Future<void> flushProgress() => _flushProgress();

  @override
  void initState() {
    super.initState();
    _progressStore = ReadingProgressStore(
      session: widget.session,
      projectRoot: widget.projectRoot,
      userScope: widget.userScope,
    );
    WidgetsBinding.instance.addObserver(this);
    _prepare();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_flushProgress());
    }
  }

  Future<void> _prepare() async {
    final size = widget.file.size;
    if (size != null && size > _maxBytes) {
      setState(() {
        _error = 'PDF 超过 100MB，暂不支持在 App 内打开';
        _loading = false;
      });
      return;
    }

    try {
      final dir = await Directory.systemTemp.createTemp('sscode_pdf_');
      final file = File('${dir.path}/document.pdf');
      final stateFuture = _progressStore.loadBestState(
        widget.hostId,
        widget.file.path,
      );
      await widget.session.downloadFile(widget.file.path, file);
      final savedState = await stateFuture;
      final progress = savedState != null
          ? (savedState.state['scrollY'] as num?)?.toDouble() ?? 0
          : await _progressStore.load(widget.hostId, widget.file.path) ?? 0;
      _zoom = savedState?.fontScale ??
          await _progressStore.loadZoom(widget.hostId, widget.file.path) ??
          1.0;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        try {
          final path = request.uri.path;
          if (path == '/document.pdf') {
            request.response.headers.contentType =
                ContentType('application', 'pdf');
            await request.response.addStream(file.openRead());
          } else if (path == '/viewer.html') {
            request.response.headers.contentType = ContentType.html;
            request.response.add(await _asset('assets/pdfjs/viewer.html'));
          } else if (path == '/pdf.min.mjs') {
            request.response.headers.contentType =
                ContentType('application', 'javascript');
            request.response.add(await _asset('assets/pdfjs/pdf.min.mjs'));
          } else if (path == '/pdf.worker.min.mjs') {
            request.response.headers.contentType =
                ContentType('application', 'javascript');
            request.response
                .add(await _asset('assets/pdfjs/pdf.worker.min.mjs'));
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
        } catch (_) {
          request.response.statusCode = HttpStatus.internalServerError;
        } finally {
          await request.response.close();
        }
      });

      if (!mounted) {
        await server.close(force: true);
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
        return;
      }

      setState(() {
        _server = server;
        _tempDir = dir;
        _webView = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(
            'DocBridge',
            onMessageReceived: (message) {
              try {
                final data =
                    jsonDecode(message.message) as Map<String, dynamic>;
                if (data['type'] == 'progress') {
                  _progressStore.save(
                    widget.hostId,
                    widget.file.path,
                    (data['scrollY'] as num).toDouble(),
                  );
                }
              } catch (_) {}
            },
          )
          ..loadRequest(
            Uri.parse(
              'http://127.0.0.1:${server.port}/viewer.html?file=/document.pdf&progress=${progress.toStringAsFixed(0)}&scale=$_zoom',
            ),
          );
        _loading = false;
      });
      _startPolling();
    } catch (error) {
      setState(() {
        _error = '打开 PDF 失败：$error';
        _loading = false;
      });
    }
  }

  Future<Uint8List> _asset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_pollProgress());
    });
  }

  Future<void> _pollProgress() async {
    if (_flushing) return;
    final scrollY = await _readScrollState();
    if (scrollY == null) return;
    final rounded = scrollY.round();
    if (rounded == _lastSavedY) return;
    _lastSavedY = rounded;
    await _progressStore.saveState(
      widget.hostId,
      widget.file.path,
      state: {'kind': 'pixels', 'scrollY': scrollY},
      fontScale: _zoom,
    );
  }

  Future<void> _flushProgress() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final scrollY = await _readScrollState();
      if (scrollY == null) return;
      _lastSavedY = scrollY.round();
      await _progressStore
          .saveState(
            widget.hostId,
            widget.file.path,
            state: {'kind': 'pixels', 'scrollY': scrollY},
            fontScale: _zoom,
            syncRemote: true,
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
    } finally {
      _flushing = false;
    }
  }

  Future<double?> _readScrollState() async {
    final webView = _webView;
    if (webView == null) return null;
    try {
      // ArkWeb JSON-encodes script results, so a numeric expression already
      // arrives as a Dart num. Never wrap it in String(...) — that would add a
      // quoting layer and break parsing.
      final value = await webView
          .runJavaScriptReturningResult('''
            (function () {
              if (!window.__ocReaderReady) return null;
              return window.scrollY;
            })()
          ''')
          .timeout(const Duration(milliseconds: 2000));
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    } catch (_) {}
    return null;
  }

  Future<void> _handleBack() async {
    if (_popping) return;
    _popping = true;
    _pollTimer?.cancel();
    await _flushProgress();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    unawaited(_flushProgress());
    _server?.close(force: true);
    final dir = _tempDir;
    if (dir != null) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
    super.dispose();
  }

  void _setZoom(double delta) {
    final next = (_zoom + delta).clamp(0.5, 3.0);
    setState(() => _zoom = next);
    _lastSavedY = null;
    _webView?.runJavaScript('setScale($next)');
    _progressStore.saveZoom(widget.hostId, widget.file.path, next);
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
          onZoomOut: () => _setZoom(-0.2),
          onZoomIn: () => _setZoom(0.2),
          onBack: () => unawaited(_handleBack()),
          canZoomOut: _zoom > 0.5,
          canZoomIn: _zoom < 3.0,
        ),
        body: _content(),
      ),
    );
  }
}
