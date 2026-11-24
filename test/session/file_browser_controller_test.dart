import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/session/file_browser_controller.dart';

void main() {
  test('requestClose closes when no guard is registered', () async {
    final c = FileBrowserController()..show();
    addTearDown(c.dispose);

    await c.requestClose();

    expect(c.visible, isFalse);
  });

  test('requestClose lets the page veto an unsaved close', () async {
    final c = FileBrowserController()..show();
    addTearDown(c.dispose);
    var asked = 0;
    c.closeGuard = () async {
      asked++;
      return false;
    };

    await c.requestClose();

    expect(asked, 1);
    expect(c.visible, isTrue);
  });

  test('requestClose closes after the page confirms', () async {
    final c = FileBrowserController()..show();
    addTearDown(c.dispose);
    c.closeGuard = () async => true;

    await c.requestClose();

    expect(c.visible, isFalse);
  });
}
