import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/session/app_session_manager.dart';
import 'package:tinydesk/session/host_session.dart';
import 'package:tinydesk/session/file_browser_controller.dart';
import 'package:tinydesk/features/documents/floating_file_browser_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeManager extends AppSessionManager {
  _FakeManager(this.controller) : super(backgroundTasks: false) {
    // Mirror AppSessionManager, which forwards every session's controller.
    controller.addListener(notifyListeners);
  }

  final FileBrowserController controller;

  @override
  FileBrowserController get fileBrowser => controller;

  @override
  List<HostSession> get sessions => const [];

  @override
  HostSession? get activeSession => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget host(FileBrowserController controller) => MaterialApp(
        home: Stack(
          children: [
            FloatingFileBrowserHost(manager: _FakeManager(controller)),
          ],
        ),
      );

  testWidgets('stays invisible until the controller shows it', (tester) async {
    final controller = FileBrowserController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    expect(find.byIcon(Icons.folder_open), findsNothing);

    controller.minimize();
    await tester.pumpWidget(host(controller));
    await tester.pump();

    expect(find.byIcon(Icons.folder_open), findsNothing);
  });

  testWidgets('shows the ball when minimized with a visible controller',
      (tester) async {
    final controller = FileBrowserController()..show();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    // Expanded shows the window (empty here because the fake has no session),
    // so the ball is hidden.
    expect(find.byIcon(Icons.folder_open), findsNothing);

    controller.minimize();
    await tester.pump();

    expect(find.byIcon(Icons.folder_open), findsOneWidget);
  });

  testWidgets('didPopRoute minimizes an expanded browser', (tester) async {
    final controller = FileBrowserController()..show();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    final handled = await tester.binding.handlePopRoute();

    expect(handled, isTrue);
    expect(controller.expanded, isFalse);
    expect(controller.visible, isTrue);
  });

  testWidgets('didPopRoute is not handled when minimized', (tester) async {
    final controller = FileBrowserController()..show()..minimize();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    final handled = await tester.binding.handlePopRoute();

    expect(handled, isFalse);
  });

  test('activeWindowIndex follows the active host', () {
    expect(activeWindowIndex(['a', 'b', 'c'], 'b'), 1);
    expect(activeWindowIndex(['a', 'b', 'c'], 'missing'), 0);
    expect(activeWindowIndex(['a', 'b', 'c'], null), 0);
    expect(activeWindowIndex(const [], 'a'), 0);
  });
}
