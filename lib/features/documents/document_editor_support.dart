import 'dart:convert';
import '../../core/app_language.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../data/remote_file.dart';
import 'file_sniff.dart';
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
      throw FormatException(AppL10n.t.fileTooLarge5MB);
    }
    final bytes = await session.readBytes(file.path);
    if (bytes.length > maxReadableBytes) {
      throw FormatException(AppL10n.t.fileTooLarge5MB);
    }
    if (looksBinary(bytes)) {
      return EditorDocument(
        text: '',
        editable: false,
        readOnlyReason: AppL10n.t.binaryContent,
      );
    }
    final tooBig = bytes.length > maxEditableBytes;
    try {
      final text = utf8.decode(bytes);
      return EditorDocument(
        text: text,
        editable: !tooBig,
        readOnlyReason: tooBig ? AppL10n.t.fileTooLarge2MB : null,
      );
    } on FormatException {
      return EditorDocument(
        text: latin1.decode(bytes),
        editable: false,
        readOnlyReason: AppL10n.t.nonUtf8,
      );
    }
  }


  /// True when the remote file changed since it was opened (size or mtime).
  ///
  /// Throws when the check itself cannot run (for example the directory
  /// listing failed), so callers can tell "unchanged" apart from "unknown"
  /// instead of silently overwriting a file they never verified.
  static Future<bool> changedOnRemote(
    TunnelSession session,
    RemoteFile opened,
  ) async {
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

  /// Asks before a save would clobber a file that changed on the server, or
  /// whose state could not be checked ([unknown]). Returns false when the user
  /// cancels or dismisses the dialog.
  static Future<bool> confirmOverwrite(
    BuildContext context, {
    bool unknown = false,
  }) async {
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(unknown
            ? AppL10n.t.remoteStateUnknownTitle
            : AppL10n.t.fileChangedRemotely),
        content: Text(
          unknown ? AppL10n.t.remoteStateUnknown : AppL10n.t.overwriteConfirm,
        ),
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
    return overwrite ?? false;
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
