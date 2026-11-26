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

  group('Cmd+~ cycle', () {
    test('nothing open does nothing', () {
      expect(
        nextOverlayStep(
          terminalOpen: false,
          browserOpen: false,
          current: FrontWindow.none,
        ),
        isNull,
      );
    });

    test('only the terminal open cycles terminal to main page to terminal', () {
      expect(
        nextOverlayStep(
          terminalOpen: true,
          browserOpen: false,
          current: FrontWindow.none,
        ),
        FrontWindow.terminal,
      );
      expect(
        nextOverlayStep(
          terminalOpen: true,
          browserOpen: false,
          current: FrontWindow.terminal,
        ),
        FrontWindow.none,
      );
    });

    test('only the browser open cycles browser to main page to browser', () {
      expect(
        nextOverlayStep(
          terminalOpen: false,
          browserOpen: true,
          current: FrontWindow.none,
        ),
        FrontWindow.fileBrowser,
      );
      expect(
        nextOverlayStep(
          terminalOpen: false,
          browserOpen: true,
          current: FrontWindow.fileBrowser,
        ),
        FrontWindow.none,
      );
    });

    test('both open cycle main page, terminal, browser', () {
      const open = (terminalOpen: true, browserOpen: true);
      expect(
        nextOverlayStep(
          terminalOpen: open.terminalOpen,
          browserOpen: open.browserOpen,
          current: FrontWindow.none,
        ),
        FrontWindow.terminal,
      );
      expect(
        nextOverlayStep(
          terminalOpen: open.terminalOpen,
          browserOpen: open.browserOpen,
          current: FrontWindow.terminal,
        ),
        FrontWindow.fileBrowser,
      );
      expect(
        nextOverlayStep(
          terminalOpen: open.terminalOpen,
          browserOpen: open.browserOpen,
          current: FrontWindow.fileBrowser,
        ),
        FrontWindow.none,
      );
    });
  });

  test('no session and no windows means native behaviour', () {
    expect(frontWindowOf(null, null), FrontWindow.none);
  });
}
