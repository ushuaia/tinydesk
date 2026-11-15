import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/remote_file.dart';
import '../../ssh/tunnel_session.dart';
import 'document_editor_support.dart';
import 'document_handle.dart';

/// Owns a CodeMirror 6 editor session for one text/code file.
///
/// Used by both the standalone reader page and the inline explorer pane, so
/// the editing behaviour (read-only default, save, conflict detection,
/// dirty tracking) is identical everywhere.
class TextDocumentController extends ChangeNotifier {
  TextDocumentController({
    required this.session,
    required this.file,
  });

  final TunnelSession session;
  final RemoteFile file;

  WebViewController? webView;
  ViewerAssetServer? _server;
  RemoteFile? _opened;

  String savedText = '';
  String buffer = '';
  DateTime? _lastModified;
  bool dirty = false;
  bool editable = false;
  bool ready = false;
  bool loading = true;
  bool saving = false;
  bool editing = false;
  String? error;
  String? readOnlyReason;

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      final doc = await DocumentEditorSupport.load(session, file);
      final server = await ViewerAssetServer.start();
      final dark = WidgetsBinding
              .instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'EditorBridge',
          onMessageReceived: _onMessage,
        )
        ..loadRequest(
          Uri.parse(
            'http://127.0.0.1:${server.port}/editor.html'
            '?file=${Uri.encodeComponent(file.name)}'
            '&readOnly=1&dark=${dark ? 1 : 0}',
          ),
        );
      if (_disposed) {
        await server.close();
        return;
      }
      _server = server;
      webView = controller;
      _opened = file;
      _lastModified = await session.statModified(file.path) ?? _lastModified;
      savedText = doc.text;
      buffer = doc.text;
      editable = doc.editable;
      readOnlyReason = doc.readOnlyReason;
      loading = false;
      _notify();
    } catch (error) {
      if (_disposed) return;
      this.error = '读取失败：$error';
      loading = false;
      _notify();
    }
  }

  /// True when the file changed on the server since this document was
  /// loaded (or last reloaded).
  Future<bool> checkExternalUpdate() async {
    if (_disposed || !ready) return false;
    final modified = await session.statModified(file.path);
    if (modified == null || _lastModified == null) return false;
    return modified.isAfter(_lastModified!);
  }

  /// Reloads the document from the server. Only called when the document has
  /// no unsaved edits; the editor keeps its scroll position via setDoc.
  Future<void> reloadFromServer() async {
    if (_disposed) return;
    try {
      final doc = await DocumentEditorSupport.load(session, file);
      if (_disposed) return;
      _lastModified = await session.statModified(file.path) ?? _lastModified;
      savedText = doc.text;
      buffer = doc.text;
      dirty = false;
      editable = doc.editable;
      readOnlyReason = doc.readOnlyReason;
      _pushContent();
      _notify();
    } catch (_) {}
  }

  void _onMessage(JavaScriptMessage message) {
    if (_disposed) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = data['type'];
    if (type == 'ready') {
      ready = true;
      _pushContent();
    } else if (type == 'change') {
      final text = data['text'] as String? ?? '';
      buffer = text;
      dirty = text != savedText;
      _notify();
    } else if (type == 'save') {
      unawaited(save());
    }
  }

  void _pushContent() {
    final controller = webView;
    if (!ready || controller == null) return;
    unawaited(
      controller.runJavaScript('window.setDoc(${jsonEncode(savedText)});'),
    );
    unawaited(controller.runJavaScript('window.setReadOnly(true);'));
  }

  void toggleMode() {
    if (!editing && !editable) return;
    editing = !editing;
    _notify();
    unawaited(
      webView?.runJavaScript('window.setReadOnly(${!editing});'),
    );
  }

  Future<bool> save() async {
    if (!editable || saving) return false;
    final opened = _opened;
    if (opened == null) return false;
    saving = true;
    _notify();
    try {
      final changed = await DocumentEditorSupport.changedOnRemote(
        session,
        opened,
      );
      if (changed && !_disposed) {
        final context = navigatorContext;
        if (context != null && context.mounted) {
          final overwrite = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('文件已在远端被修改'),
              content: const Text('保存会覆盖远端的最新内容，是否继续？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('覆盖'),
                ),
              ],
            ),
          );
          if (overwrite != true) return false;
        }
      }
      await session.writeText(file.path, buffer);
      if (_disposed) return false;
      savedText = buffer;
      dirty = false;
      _opened = DocumentEditorSupport.withSavedContent(opened, buffer);
      _notify();
      return true;
    } catch (error) {
      if (!_disposed) {
        errorMessage = '保存失败：$error';
        _notify();
      }
      return false;
    } finally {
      saving = false;
      if (!_disposed) _notify();
    }
  }

  /// Last save error, for the host UI to display.
  String? errorMessage;

  /// Context used for dialogs; set by the hosting widget.
  BuildContext? navigatorContext;

  Future<bool> confirmDiscard(BuildContext context) async {
    if (!dirty) return true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的修改'),
        content: Text('${file.name} 有未保存的修改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('放弃'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (action == 'save') {
      await save();
      return !dirty;
    }
    return action == 'discard';
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_server?.close());
    super.dispose();
  }
}

/// Embeddable CodeMirror body (no Scaffold/AppBar).
class TextDocumentView extends StatelessWidget {
  const TextDocumentView({super.key, required this.controller});

  final TextDocumentController controller;

  @override
  Widget build(BuildContext context) {
    controller.navigatorContext = context;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(controller.error!),
            ),
          );
        }
        final webView = controller.webView;
        if (webView == null) {
          return const Center(child: Text('编辑器未就绪'));
        }
        return WebViewWidget(controller: webView);
      },
    );
  }
}


/// Header-ready wrapper used by the unified files page.
class TextDocumentHandle extends DocumentHandle {
  TextDocumentHandle({required this.controller}) {
    controller.addListener(_forward);
    unawaited(controller.load());
  }

  final TextDocumentController controller;

  void _forward() => notifyListeners();

  @override
  String get title => controller.file.name;

  @override
  BuildContext? get navigatorContext => controller.navigatorContext;

  @override
  set navigatorContext(BuildContext? value) =>
      controller.navigatorContext = value;

  @override
  bool get dirty => controller.dirty;

  @override
  Future<bool> checkExternalUpdate() => controller.checkExternalUpdate();

  @override
  Future<void> reloadExternalChanges() => controller.reloadFromServer();

  @override
  String? get readOnlyReason => controller.readOnlyReason;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (controller.dirty)
        IconButton(
          onPressed: controller.saving
              ? null
              : () async {
                  final saved = await controller.save();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        saved
                            ? '已保存'
                            : (controller.errorMessage ?? '保存失败'),
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.save_outlined),
          iconSize: 18,
          tooltip: '保存',
        ),
      IconButton(
        onPressed: controller.loading || controller.error != null
            ? null
            : () {
                if (!controller.editing && !controller.editable) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        controller.readOnlyReason ?? '该文件不支持编辑',
                      ),
                    ),
                  );
                  return;
                }
                controller.toggleMode();
              },
        icon: Icon(
          controller.editing
              ? Icons.visibility_outlined
              : Icons.edit_outlined,
        ),
        iconSize: 18,
        tooltip: controller.editing ? '阅读' : '编辑',
      ),
    ];
  }

  @override
  Widget buildBody(BuildContext context) =>
      TextDocumentView(controller: controller);

  @override
  Future<bool> confirmClose(BuildContext context) async {
    final ok = await controller.confirmDiscard(context);
    if (!ok) return false;
    controller.removeListener(_forward);
    controller.dispose();
    return true;
  }

  @override
  Future<void> close() async {
    controller.removeListener(_forward);
    controller.dispose();
  }
}
