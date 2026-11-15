import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/file_browser_controller.dart';

void main() {
  test('starts hidden', () {
    final controller = FileBrowserController();
    expect(controller.visible, isFalse);
    expect(controller.expanded, isFalse);
    expect(controller.pendingFile, isNull);
  });

  test('show makes the ball visible and the window expanded', () {
    final controller = FileBrowserController()..show();
    expect(controller.visible, isTrue);
    expect(controller.expanded, isTrue);
  });

  test('minimize keeps the ball visible', () {
    final controller = FileBrowserController()..show();
    controller.minimize();
    expect(controller.visible, isTrue);
    expect(controller.expanded, isFalse);
  });

  test('close hides everything', () {
    final controller = FileBrowserController()..show();
    controller.close();
    expect(controller.visible, isFalse);
    expect(controller.expanded, isFalse);
  });

  test('minimize is a no-op when already minimized', () {
    final controller = FileBrowserController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.minimize();
    controller.close();
    expect(notifications, 0);
  });

  test('pending file is consumed once', () {
    const file = RemoteFile(name: 'a.md', path: '/p/a.md', isDirectory: false);
    final controller = FileBrowserController()..requestOpenFile(file);
    expect(controller.pendingFile, same(file));
    controller.consumePendingFile();
    expect(controller.pendingFile, isNull);
  });

  test('notifies on each transition', () {
    final controller = FileBrowserController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.show();
    controller.minimize();
    controller.close();
    expect(notifications, 3);
  });

  test('each open request gets a new id', () {
    const file = RemoteFile(name: 'a.md', path: '/p/a.md', isDirectory: false);
    final controller = FileBrowserController();
    final first = controller.pendingRequestId;

    controller.requestOpenFile(file);
    final second = controller.pendingRequestId;
    controller.requestOpenFile(file);

    expect(second, greaterThan(first));
    expect(controller.pendingRequestId, greaterThan(second));
  });

  test('stores the project root of the pending request', () {
    const file = RemoteFile(name: 'a.md', path: '/p/a.md', isDirectory: false);
    final controller = FileBrowserController()
      ..requestOpenFile(file, projectRoot: '/project');

    expect(controller.pendingProjectRoot, '/project');
  });
}
