import 'package:flutter/foundation.dart';

import '../../data/remote_file.dart';

/// Per-session state of the floating file browser.
///
/// Only the window chrome lives here. The browsing state (current path,
/// expanded folders, open document, unsaved edits) stays inside
/// `RemoteFileBrowserPage` and is kept alive by the host's IndexedStack.
class FileBrowserController extends ChangeNotifier {
  bool _visible = false;
  bool _expanded = false;
  RemoteFile? _pendingFile;
  int _pendingRequestId = 0;
  String _pendingProjectRoot = '';

  bool get visible => _visible;

  bool get expanded => _expanded;

  RemoteFile? get pendingFile => _pendingFile;

  /// Increments on every request so the page can tell two requests for the
  /// same [RemoteFile] instance apart.
  int get pendingRequestId => _pendingRequestId;

  /// Project root captured with the pending request (used to seed reads and
  /// favorites for the file that opened the window).
  String get pendingProjectRoot => _pendingProjectRoot;

  void show() {
    final changed = !_visible || !_expanded;
    _visible = true;
    _expanded = true;
    if (changed) notifyListeners();
  }

  void minimize() {
    if (!_expanded) return;
    _expanded = false;
    notifyListeners();
  }

  void close() {
    if (!_visible && !_expanded) return;
    _visible = false;
    _expanded = false;
    _pendingFile = null;
    _pendingRequestId = 0;
    _pendingProjectRoot = '';
    notifyListeners();
  }

  void requestOpenFile(RemoteFile file, {String projectRoot = ''}) {
    _pendingFile = file;
    _pendingProjectRoot = projectRoot;
    _pendingRequestId++;
    notifyListeners();
  }

  void consumePendingFile() {
    if (_pendingFile == null) return;
    _pendingFile = null;
    notifyListeners();
  }
}
