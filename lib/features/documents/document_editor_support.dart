import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../data/remote_file.dart';
import '../../ssh/tunnel_session.dart';

class EditorDocument {
  const EditorDocument({
    required this.text,
    required this.editable,
    this.readOnlyReason,
  });

  final String text;
  final bool editable;
  final String? readOnlyReason;
}

/// Shared loading / safety / conflict logic for the WebView editors
/// (CodeMirror 6 for text files, the markdown viewer for .md).
class DocumentEditorSupport {
  static const maxEditableBytes = 2 * 1024 * 1024;
  static const maxReadableBytes = 5 * 1024 * 1024;

  static Future<EditorDocument> load(
    TunnelSession session,
    RemoteFile file,
  ) async {
    final declaredSize = file.size;
    if (declaredSize != null && declaredSize > maxReadableBytes) {
      throw const FormatException('文件超过 5MB，暂不支持在 App 内打开');
    }
    final bytes = await session.readBytes(file.path);
    if (bytes.length > maxReadableBytes) {
      throw const FormatException('文件超过 5MB，暂不支持在 App 内打开');
    }
    if (_looksBinary(bytes)) {
      return EditorDocument(
        text: '',
        editable: false,
        readOnlyReason: '检测到二进制内容，无法编辑',
      );
    }
    final tooBig = bytes.length > maxEditableBytes;
    try {
      final text = utf8.decode(bytes);
      return EditorDocument(
        text: text,
        editable: !tooBig,
        readOnlyReason: tooBig ? '文件超过 2MB，只读打开' : null,
      );
    } on FormatException {
      return EditorDocument(
        text: latin1.decode(bytes),
        editable: false,
        readOnlyReason: '非 UTF-8 编码，只读打开',
      );
    }
  }

  static bool _looksBinary(Uint8List bytes) {
    final limit = math.min(bytes.length, 8192);
    for (var index = 0; index < limit; index++) {
      if (bytes[index] == 0) return true;
    }
    return false;
  }

  /// True when the remote file changed since it was opened (size or mtime).
  static Future<bool> changedOnRemote(
    TunnelSession session,
    RemoteFile opened,
  ) async {
    try {
      final slash = opened.path.lastIndexOf('/');
      final dir = slash <= 0 ? '/' : opened.path.substring(0, slash);
      final files = await session.listDirectory(dir);
      RemoteFile? current;
      for (final item in files) {
        if (item.name == opened.name) {
          current = item;
          break;
        }
      }
      if (current == null) return true;
      if (opened.size != null &&
          current.size != null &&
          current.size != opened.size) {
        return true;
      }
      if (opened.modifiedAt != null &&
          current.modifiedAt != null &&
          current.modifiedAt!.isAfter(opened.modifiedAt!)) {
        return true;
      }
      return false;
    } catch (_) {
      // Cannot verify: let the save proceed rather than blocking the user.
      return false;
    }
  }

  static RemoteFile withSavedContent(RemoteFile opened, String content) {
    return RemoteFile(
      name: opened.name,
      path: opened.path,
      isDirectory: false,
      size: utf8.encode(content).length,
      modifiedAt: DateTime.now(),
    );
  }
}

/// Serves the bundled viewer assets over loopback (WebView needs http://).
class ViewerAssetServer {
  ViewerAssetServer._(this._server);

  final HttpServer _server;

  int get port => _server.port;

  static Future<ViewerAssetServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = ViewerAssetServer._(server);
    server.listen(instance._handle);
    return instance;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (path == '/editor.html') {
        request.response.headers.contentType = ContentType.html;
        request.response.add(await _asset('assets/viewer/editor.html'));
      } else if (path == '/codemirror.bundle.js') {
        request.response.headers.contentType =
            ContentType('application', 'javascript');
        request.response.add(
          await _asset('assets/viewer/codemirror.bundle.js'),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
    } finally {
      await request.response.close();
    }
  }

  Future<List<int>> _asset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  Future<void> close() => _server.close(force: true);
}
