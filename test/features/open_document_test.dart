import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/core/app_session_manager.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/file_browser_controller.dart';
import 'package:tinydesk/features/documents/open_document.dart';

class _FakeManager extends AppSessionManager {
  _FakeManager(this.controller) : super(backgroundTasks: false);

  final FileBrowserController controller;

  @override
  FileBrowserController get fileBrowser => controller;

  @override
  void showFileBrowser() => controller.show();
}

void main() {
  testWidgets('openDocument shows the floating browser with a pending file',
      (tester) async {
    const file = RemoteFile(name: 'a.md', path: '/p/a.md', isDirectory: false);
    final controller = FileBrowserController();
    final manager = _FakeManager(controller);
    addTearDown(controller.dispose);
    addTearDown(manager.dispose);
    late BuildContext context;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    ));

    final opened = await openDocument(
      context,
      manager: manager,
      file: file,
      projectRoot: '/project',
      controller: controller,
    );

    expect(opened, isTrue);
    expect(controller.visible, isTrue);
    expect(controller.expanded, isTrue);
    expect(controller.pendingFile, same(file));
    expect(controller.pendingProjectRoot, '/project');
  });

  testWidgets('openDocument rejects unsupported files', (tester) async {
    const file = RemoteFile(name: 'a.xyz', path: '/p/a.xyz', isDirectory: false);
    final controller = FileBrowserController();
    final manager = _FakeManager(controller);
    addTearDown(controller.dispose);
    addTearDown(manager.dispose);
    late BuildContext context;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    ));

    final opened = await openDocument(
      context,
      manager: manager,
      file: file,
      projectRoot: '/p',
      controller: controller,
    );

    expect(opened, isFalse);
    expect(controller.visible, isFalse);
  });
}
