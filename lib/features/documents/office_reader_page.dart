import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/remote_file.dart';
import '../../ssh/tunnel_session.dart';

/// Read-only viewer for CSV, Excel (.xlsx/.xls) and Word (.docx) files.
///
/// Everything runs locally: the file, HTML and JS bundles are served from a
/// loopback HttpServer, so no network access is required.
class OfficeReaderPage extends StatefulWidget {
  const OfficeReaderPage({
    super.key,
    required this.session,
    required this.file,
    this.embedded = false,
  });

  final TunnelSession session;
  final RemoteFile file;
  final bool embedded;

  @override
  State<OfficeReaderPage> createState() => _OfficeReaderPageState();
}

class _OfficeReaderPageState extends State<OfficeReaderPage> {
  static const _maxBytes = 50 * 1024 * 1024;

  HttpServer? _server;
  Directory? _tempDir;
  WebViewController? _webView;
  String? _error;
  bool _loading = true;

  String get _type {
    if (widget.file.isCsv) return 'csv';
    if (widget.file.isSpreadsheet) return 'xlsx';
    return 'docx';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final size = widget.file.size;
    if (size != null && size > _maxBytes) {
      setState(() {
        _error = '文件超过 50MB，暂不支持在 App 内打开';
        _loading = false;
      });
      return;
    }

    try {
      final dir = await Directory.systemTemp.createTemp('tinydesk_office_');
      final file = File('${dir.path}/document.${widget.file.extension}');
      await widget.session.downloadFile(widget.file.path, file);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        try {
          final path = request.uri.path;
          if (path == '/file') {
            request.response.headers.contentType =
                ContentType('application', 'octet-stream');
            await request.response.addStream(file.openRead());
          } else if (path == '/office.html') {
            request.response.headers.contentType = ContentType.html;
            request.response.add(await _asset('assets/viewer/office.html'));
          } else if (path == '/vendor/xlsx.full.min.js') {
            request.response.headers.contentType =
                ContentType('application', 'javascript');
            request.response.add(
              await _asset('assets/vendor/xlsx.full.min.js'),
            );
          } else if (path == '/vendor/mammoth.browser.min.js') {
            request.response.headers.contentType =
                ContentType('application', 'javascript');
            request.response.add(
              await _asset('assets/vendor/mammoth.browser.min.js'),
            );
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
          ..loadRequest(
            Uri.parse(
              'http://127.0.0.1:${server.port}/office.html?type=$_type',
            ),
          );
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = '打开文件失败：$error';
        _loading = false;
      });
    }
  }

  Future<Uint8List> _asset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  @override
  void dispose() {
    _server?.close(force: true);
    final dir = _tempDir;
    if (dir != null) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          tooltip: '返回',
        ),
        titleTextStyle: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          widget.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _content(),
    );
  }
}
