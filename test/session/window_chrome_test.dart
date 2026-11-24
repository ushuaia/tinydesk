import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tinydesk/session/file_browser_controller.dart';
import 'package:tinydesk/session/terminal_controller.dart';
import 'package:tinydesk/session/window_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TerminalController terminal() =>
      TerminalController(sessionProvider: () => null);

  test('an expanded terminal is the front window', () {
    final t = terminal()..visible = true..expanded = true;
    addTearDown(t.dispose);
    expect(frontWindowOf(t, null), FrontWindow.terminal);
  });

  test('a terminal ball is not a front window', () {
    final t = terminal()..visible = true..expanded = false;
    addTearDown(t.dispose);
    expect(frontWindowOf(t, null), FrontWindow.none);
  });

  test('a terminal ball does not hide an expanded file browser', () {
    final t = terminal()..visible = true..expanded = false;
    final b = FileBrowserController()..show();
    addTearDown(t.dispose);
    addTearDown(b.dispose);
    expect(frontWindowOf(t, b), FrontWindow.fileBrowser);
  });

  test('the terminal wins when both windows are expanded', () {
    final t = terminal()..visible = true..expanded = true;
    final b = FileBrowserController()..show();
    addTearDown(t.dispose);
    addTearDown(b.dispose);
    expect(frontWindowOf(t, b), FrontWindow.terminal);
  });

  test('no session and no windows means native behaviour', () {
    expect(frontWindowOf(null, null), FrontWindow.none);
  });
}
