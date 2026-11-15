import 'package:flutter/material.dart';

import '../../core/app_session_manager.dart';
import '../../data/remote_file.dart';
import 'file_browser_controller.dart';

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
        SnackBar(content: Text('暂不支持打开 .${file.extension} 文件')),
      );
    }
    return false;
  }

  controller.requestOpenFile(file, projectRoot: projectRoot);
  manager.showFileBrowser();
  return true;
}
