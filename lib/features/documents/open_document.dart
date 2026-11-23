import 'package:flutter/material.dart';
import '../../core/app_language.dart';


import '../../session/app_session_manager.dart';
import '../../data/remote_file.dart';
import '../../session/file_browser_controller.dart';

bool _isSupported(RemoteFile file) {
  return file.isMarkdown ||
      file.isPdf ||
      file.isCsv ||
      file.isSpreadsheet ||
      file.isWord ||
      file.isImage ||
      file.isText;
}

/// Opens a file in the unified files page (inline content).
Future<bool> openDocument(
  BuildContext context, {
  required AppSessionManager manager,
  required RemoteFile file,
  required FileBrowserController controller,
  String projectRoot = '',
}) async {
  if (!_isSupported(file)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.unsupportedFile(file.extension))),
      );
    }
    return false;
  }

  controller.requestOpenFile(file, projectRoot: projectRoot);
  manager.showFileBrowser();
  return true;
}
